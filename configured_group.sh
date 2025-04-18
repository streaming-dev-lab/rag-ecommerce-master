#!/bin/sh

current_dir=$(pwd)
gp_name=$(echo "$current_dir" | cut -d'/' -f3)

echo "Directory name: $gp_name"

sed -i "s/VM_OWNER=.*/VM_OWNER=${gp_name}/g" config_aws.properties
sed -i "s/CONFLUENT_CLOUD_ENVIRONMENT=.*/CONFLUENT_CLOUD_ENVIRONMENT=${gp_name}/g" config_aws.properties
sed -i "s/Name = \"bastion\"/Name = \"${gp_name}\"/g" terraform/main.tf
sed -i 's/name = "allow_ssh_\${random_id\.id\.id}"/name = "allow_ssh_'"$gp_name"'"/g' terraform/main.tf
sed -i 's/key_name = "pub_\${random_id\.id\.id}"/key_name = "pub_'"$gp_name"'"/g' terraform/main.tf

sed -i 's/display_name = "app-manager_\${random_id\.id\.id}"/display_name = "app-manager_'"$gp_name"'"/g' terraform/ecommerce.tf
sed -i 's/display_name = "statements-runner_\${random_id\.id\.id}"/display_name = "statements-runner_'"$gp_name"'"/g' terraform/ecommerce.tf
sed -i 's/display_name = "app-manager-kafka-api-key"/display_name = "app-manager-kafka-api-key-'"$gp_name"'"/g' terraform/ecommerce.tf
sed -i 's/display_name = "env-manager-schema-registry-api-key"/display_name = "env-manager-schema-registry-api-key-'"$gp_name"'"/g' terraform/ecommerce.tf
sed -i "s/fa560f9da14/${gp_name}/g" terraform/ecommerce.tf

echo "Configured group to → '$gp_name'"