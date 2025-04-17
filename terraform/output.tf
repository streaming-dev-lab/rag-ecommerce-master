resource "local_file" "config"{
        filename = "${path.cwd}/../etc/kafka.properties"
	content = <<-EOT
# Required connection configs for Kafka producer, consumer, and admin
bootstrap.servers=${replace(confluent_kafka_cluster.basic.bootstrap_endpoint, "SASL_SSL://", "")}
security.protocol=SASL_SSL
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='${confluent_api_key.app-manager-kafka-api-key.id}' password='${confluent_api_key.app-manager-kafka-api-key.secret}';
sasl.mechanism=PLAIN
# Required for correctness in Apache Kafka clients prior to 2.6
client.dns.lookup=use_all_dns_ips

# Best practice for higher availability in Apache Kafka clients prior to 3.0
session.timeout.ms=45000

# Best practice for Kafka producer to prevent data loss
acks=all

# Required connection configs for Confluent Cloud Schema Registry
schema.registry.url=${data.confluent_schema_registry_cluster.sr.rest_endpoint}
basic.auth.credentials.source=USER_INFO
basic.auth.user.info={{ SR_API_KEY }}:{{ SR_API_SECRET }}
  EOT
}

/*
resource "local_file" "vars"{
  filename = "${path.cwd}/../etc/vars.sh"
  content = <<-EOT
#!/usr/bin/env bash
ENV_ID=${confluent_environment.ecommerce.id}
BOOTSTRAP_SERVER=${replace(confluent_kafka_cluster.basic.bootstrap_endpoint, "SASL_SSL://", "")} 
API_KEY=${confluent_api_key.app-manager-kafka-api-key.id}
API_SECRET=${confluent_api_key.app-manager-kafka-api-key.secret}
KSQLDB_ENDPOINT=${confluent_ksql_cluster.app.rest_endpoint}
KSQLDB_ID=${confluent_ksql_cluster.app.id}
  EOT
}
*/

resource "local_file" "py_config" {
	filename = "${path.cwd}/../etc/client.properties"
	content= <<-EOT
bootstrap.servers=${replace(confluent_kafka_cluster.basic.bootstrap_endpoint, "SASL_SSL://", "")}
security.protocol=SASL_SSL
sasl.mechanisms=PLAIN
sasl.username=${confluent_api_key.app-manager-kafka-api-key.id}
sasl.password=${confluent_api_key.app-manager-kafka-api-key.secret}

# Best practice for higher availability in librdkafka clients prior to 1.7
session.timeout.ms=45000

group.id=rag
auto.offset.reset=earliest
isolation.level=read_uncommitted

EOT
}

resource "local_file" "py_sr_config"{
	filename = "${path.cwd}/../etc/sr.properties"
	content = <<-EOT
url=${data.confluent_schema_registry_cluster.sr.rest_endpoint}
basic.auth.user.info=${confluent_api_key.app-manager-schema-registry-api-key.id}:${confluent_api_key.app-manager-schema-registry-api-key.secret}

EOT
}

resource "local_file" "compose_env" {
	filename = "${path.cwd}/../etc/.env"
	content = <<-EOT
MYSQL_ROOT_PASSWORD=${var.db_password}
MYSQL_PASSWORD=${var.db_password}
VM_PUBLIC_IP=${aws_instance.bastion.public_ip}
OPENAI_API_KEY=${var.open_api_key}
SHOP_BASE_URL=http://${aws_instance.bastion.public_ip}/
EOT
}

resource "local_file" "information"{
	filename = "${path.cwd}/../etc/information.properties"
	content = <<-EOT
Shop=                   http://${aws_instance.bastion.public_ip}
Admin=                  http://${aws_instance.bastion.public_ip}/admin2 (demo@prestashop.com/prestashop_demo)
AI_Playground=          http://${aws_instance.bastion.public_ip}:8001/chat/playground/
MySQL=                  ${aws_instance.bastion.public_ip}:3306 (root/P@ssw0rd)
Chroma_DB=              http://${aws_instance.bastion.public_ip}:8501/
Confluent_API_KEY=      ${confluent_api_key.app-manager-kafka-api-key.id}
Confluent_API_SECRET=   ${confluent_api_key.app-manager-kafka-api-key.secret}
EOT
}

output "cluster"{
	value = confluent_kafka_cluster.basic.bootstrap_endpoint
}

output "sr_endpoint"{
	value = data.confluent_schema_registry_cluster.sr.rest_endpoint
}

output "urls" {
	value =<<-EOT
Shop: 			        http://${aws_instance.bastion.public_ip}
Admin:  		        http://${aws_instance.bastion.public_ip}/admin2 (demo@prestashop.com/prestashop_demo)
AI Playground: 	        http://${aws_instance.bastion.public_ip}:8001/chat/playground/
MySQL:                  ${aws_instance.bastion.public_ip}:3306 (root/P@ssw0rd)
Chroma DB:              http://${aws_instance.bastion.public_ip}:8501/
Confluent API_KEY:      ${confluent_api_key.app-manager-kafka-api-key.id}
Confluent API_SECRET:   ${confluent_api_key.app-manager-kafka-api-key.secret}
EOT
    sensitive = true
}



