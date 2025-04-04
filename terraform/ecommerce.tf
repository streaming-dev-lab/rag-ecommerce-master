# Configure the Confluent Provider
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.1.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key    # optionally use CONFLUENT_CLOUD_API_KEY env var
  cloud_api_secret = var.confluent_cloud_api_secret # optionally use CONFLUENT_CLOUD_API_SECRET env var
}

resource "confluent_environment" "ecommerce" {
  display_name = "ecommerce_${var.confluent_cloud_environment}"

  stream_governance {
    package = "ESSENTIALS"
  }
}

data "confluent_schema_registry_cluster" "sr" {
  environment {
    id = confluent_environment.ecommerce.id
  }
  depends_on = [
    confluent_kafka_cluster.basic
  ]
}

resource "confluent_kafka_cluster" "basic" {
  display_name = "ecommerce-poc"
  availability = "SINGLE_ZONE"
  cloud        = var.cloud
  region       = var.region
  basic {}

  environment {
    id = confluent_environment.ecommerce.id
  }
}

resource "confluent_flink_compute_pool" "main" {
  display_name     = "standard_compute_pool"
  cloud            = "AWS"
  region           = var.region
  max_cfu          = 5
  environment {
    id = confluent_environment.ecommerce.id
  }
}



resource "confluent_service_account" "app-manager" {
  display_name = "app-manager_${random_id.id.id}"
  description  = "Service account to manage 'inventory' Kafka cluster"

  depends_on = [
    confluent_kafka_cluster.basic
  ]
  
}

data "confluent_organization" "main" {}
resource "confluent_service_account" "statements-runner" {
  display_name = "statements-runner_${random_id.id.id}"
  description  = "Service account for running Flink Statements in 'inventory' Kafka cluster"
}

resource "confluent_role_binding" "app-manager-env-admin" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.ecommerce.resource_name
}

resource "confluent_role_binding" "statements-runner-env-admin" {
  principal   = "User:${confluent_service_account.statements-runner.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.ecommerce.resource_name
}

resource "confluent_role_binding" "app-manager-flink-developer" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.ecommerce.resource_name
}
resource "confluent_role_binding" "app-manager-assigner" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "Assigner"
  crn_pattern = "${data.confluent_organization.main.resource_name}/service-account=${confluent_service_account.statements-runner.id}"
}


data "confluent_flink_region" "region" {
  cloud  = "AWS"
  region = confluent_kafka_cluster.basic.region
}

resource "confluent_api_key" "app-manager-kafka-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.ecommerce.id
    }
  }
}

resource "confluent_api_key" "app-manager-schema-registry-api-key" {
  display_name = "env-manager-schema-registry-api-key"
  description  = "Schema Registry API Key that is owned by 'env-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind

    environment {
      id = confluent_environment.ecommerce.id
    }
  }

}

resource "confluent_api_key" "app-manager-flink-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.region.id
    api_version = data.confluent_flink_region.region.api_version
    kind        = data.confluent_flink_region.region.kind

    environment {
      id = confluent_environment.ecommerce.id
    }
  }
}

resource "confluent_kafka_acl" "app-manager-write-on-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = "fa560f9da14"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-manager-read-on-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = "cart_priced"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-manager-create-on-topic-dlq" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = "dlq-lcc"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "CREATE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-manager-write-on-topic-dlq" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = "dlq-lcc"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-manager-read-on-topic-connect" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "GROUP"
  resource_name = "connect-lcc"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-manager.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

resource "confluent_flink_statement" "products_ddl" {
  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.ecommerce.id
  }

  statement  = <<-EOT
CREATE TABLE products (
  `key` BIGINT NOT NULL,
  `available_for_order` BOOLEAN,
  `quantity` INT,
  `uri` string,
  `description` string,
  `description_short` string,
  CONSTRAINT `PRIMARY` PRIMARY KEY (`key`) NOT ENFORCED
);
EOT
  properties = {
    "sql.current-catalog"  = confluent_environment.ecommerce.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.region.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_flink_compute_pool.main,
    confluent_connector.source,
    confluent_role_binding.app-manager-assigner,
    confluent_role_binding.app-manager-flink-developer
  ]
}
resource "confluent_flink_statement" "products_dml" {
  compute_pool {
    id = confluent_flink_compute_pool.main.id
  }
  principal {
    id = confluent_service_account.statements-runner.id
  }
  organization {
    id = data.confluent_organization.main.id
  }
  environment {
    id = confluent_environment.ecommerce.id
  }

  statement  = <<-EOT
insert into products
select
    p.id_product,
    p.after.available_for_order =1,
    p.after.quantity,
    concat(
        c.after.link_rewrite, '/' ,
        cast(p.id_product as string) , '-' ,
        cast (p.after.cache_default_attribute as string), '-' ,
        pl.after.link_rewrite , '.html' ),
    pl.after.description,
    pl.after.description_short
from `fa560f9da14.prestashop.ps_product` p join `fa560f9da14.prestashop.ps_product_lang` pl on p.id_product = pl.id_product
left join `fa560f9da14.prestashop.ps_category_product` cp on pl.id_product=cp.id_product and p.after.id_category_default = cp.id_category
left join `fa560f9da14.prestashop.ps_category_lang` c on cp.id_category = c.id_category;
EOT
  properties = {
    "sql.current-catalog"  = confluent_environment.ecommerce.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }
  rest_endpoint   = data.confluent_flink_region.region.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-flink-api-key.id
    secret = confluent_api_key.app-manager-flink-api-key.secret
  }

  depends_on = [
    confluent_flink_compute_pool.main,
    confluent_connector.source,
    confluent_role_binding.app-manager-assigner,
    confluent_role_binding.app-manager-flink-developer,
    confluent_flink_statement.products_ddl
  ]
}

resource "confluent_connector" "source" {
  environment {
    id = confluent_environment.ecommerce.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_sensitive = {}

  config_nonsensitive = {
  "name"                      ="CDC_source"
  "connector.class"           ="MySqlCdcSourceV2"
  "database.hostname"         = aws_instance.bastion.public_ip
  "database.include.list"     ="prestashop"
  "database.password"         = var.db_password
  "database.port"             ="3306"
  "topic.prefix"      ="fa560f9da14"
  "database.ssl.mode"         ="preferred"
  "database.user"             = "root"
  "json.output.decimal.format"="NUMERIC"
  "kafka.api.key"             =confluent_api_key.app-manager-kafka-api-key.id
  "kafka.api.secret"          =confluent_api_key.app-manager-kafka-api-key.secret
  "kafka.auth.mode"           ="KAFKA_API_KEY"
  "max.batch.size"            ="1000"
  "output.data.format"        ="AVRO"
  "output.key.format"         ="AVRO"
  "poll.interval.ms"          ="500"
  "errors.deadletterqueue.topic.name" = "db.errors"
  "snapshot.mode"             ="when_needed"
  "table.include.list"        ="prestashop.ps_category_lang, prestashop.ps_cart_product, prestashop.ps_product, prestashop.ps_product_lang,prestashop.ps_category_product"
  "tasks.max"                 ="1"
  "database.history.skip.unparseable.ddl"="true"


  }
  depends_on = [
    confluent_role_binding.app-manager-env-admin
  ]

}

