#!/usr/bin/env bash
set -e
if [[ "$CONFIG_FILE" == "" ]] || [[ ! -e $CONFIG_FILE ]]; then
	echo "Please provide an environment variable CONFIG_FILE with the path of the config file"
	exit 1
fi
echo Config file: $CONFIG_FILE
. $CONFIG_FILE
export AWS_REGION
export AWS_ACCESS_KEY
export AWS_SECRET_KEY
export SSH_PUB_KEY_FILE
export VM_OWNER
export MYSQL_ROOT_PASSWORD
export MYSQL_PASSWORD
export CONFLUENT_CLOUD_API_KEY
export CONFLUENT_CLOUD_API_SECRET
export CONFLUENT_CLOUD_REGION
export CONFLUENT_CLOUD_PROVIDER
export CONFLUENT_CLOUD_ENVIRONMENT

#echo $CONFLUENT_CLOUD_API_KEY
#echo $CONFLUENT_CLOUD_API_SECRET

cat <<EOF > terraform/terraform.tfvars
aws_region="$AWS_REGION"
aws_owner="$VM_OWNER"
aws_access_key="$AWS_ACCESS_KEY"
aws_secret_key="$AWS_SECRET_KEY"
public_key_file_path="$SSH_PUB_KEY_FILE"
confluent_cloud_api_key="$CONFLUENT_CLOUD_API_KEY"
confluent_cloud_api_secret="$CONFLUENT_CLOUD_API_SECRET"
confluent_cloud_environment="$CONFLUENT_CLOUD_ENVIRONMENT"
region="$AWS_REGION"
cloud="$CONFLUENT_CLOUD_PROVIDER"
db_password="$MYSQL_PASSWORD"
open_api_key="$OPENAI_API_KEY"
EOF


wait_for () {
  set +e
	local function_to_check=$1
	local name=$2

	local retries=0
	local max_retries=100
	local sleep_delay=5
	until $function_to_check
	do
		retries=$(($retries+1))
		if [ $retries -gt $max_retries ]; then
			echo Timeout waiting for $name readiness
			exit 1
		fi
		sleep $sleep_delay
		echo $name is not ready, retrying
	done
	echo $name ready!
	set -e
}

cd terraform
terraform init -upgrade
terraform apply -target local_file.ip_bastion -target local_file.compose_env -auto-approve

#set -x
vm_pub_ip=$(cat tmp/commerce_bastion_ip.txt)
echo VM public IP: $vm_pub_ip
cd ..
## To avoid IP reuse with different keys
# ssh_options="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
ssh_options="-i data.key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

check_ssh () {
	ssh $ssh_options ec2-user@$vm_pub_ip echo OK
}

wait_for check_ssh "SSH"

scp $ssh_options etc/.env ec2-user@$vm_pub_ip:~/
scp $ssh_options rag/indexer.py ec2-user@$vm_pub_ip:~/
scp $ssh_options rag/api.py ec2-user@$vm_pub_ip:~/
scp $ssh_options rag/requirements.txt ec2-user@$vm_pub_ip:~/
scp $ssh_options rag/compose.yml ec2-user@$vm_pub_ip:~/compose_rag.yml
scp $ssh_options rag/indexer.yml ec2-user@$vm_pub_ip:~/indexer.yml
scp $ssh_options ps_sample_compose.yml ec2-user@$vm_pub_ip:~/
scp $ssh_options init-scripts/post-init.sh ec2-user@$vm_pub_ip:~/
scp -r $ssh_options chroma-peek ec2-user@$vm_pub_ip:~/

check_docker() {
  ssh $ssh_options ec2-user@$vm_pub_ip docker ps
}

wait_for check_docker "Docker"


ssh $ssh_options ec2-user@$vm_pub_ip docker run -d \
	--name compose \
	-v \$PWD:/work  \
	--workdir /work \
       	-v /var/run/docker.sock:/var/run/docker.sock \
       	docker compose -f ps_sample_compose.yml up -d

check_shop () {
	curl --fail --max-time 10 $vm_pub_ip
}

wait_for check_shop "Shop"

cd terraform
terraform init
terraform apply -auto-approve

cd ..

scp $ssh_options etc/client.properties ec2-user@$vm_pub_ip:~/
scp $ssh_options etc/sr.properties ec2-user@$vm_pub_ip:~/
scp $ssh_options etc/information.properties ec2-user@$vm_pub_ip:~/

ssh $ssh_options ec2-user@$vm_pub_ip docker run -d \
	--name compose_rag \
	-v \$PWD:/work  \
	--workdir /work \
       	-v /var/run/docker.sock:/var/run/docker.sock \
       	docker compose -f compose_rag.yml up -d

echo Now you can visit the shop at http://$vm_pub_ip 
cd terraform
terraform output

