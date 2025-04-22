# Add permission to login with password
# Add this to end of line in /etc/ssh/sshd_config (sudo vim /etc/ssh/sshd_config)
Match Group deployer
  PasswordAuthentication yes
  Match all

# Create user group and password (password is p@sswXrd where "X" is number of group)
sudo useradd -m -g deployer gp1
echo "gp1:p@ssw1rd" | sudo chpasswd
sudo useradd -m -g deployer gp2
echo "gp2:p@ssw2rd" | sudo chpasswd
sudo useradd -m -g deployer gp3
echo "gp3:p@ssw3rd" | sudo chpasswd
sudo useradd -m -g deployer gp4
echo "gp4:p@ssw4rd" | sudo chpasswd
sudo useradd -m -g deployer gp5
echo "gp5:p@ssw5rd" | sudo chpasswd
sudo useradd -m -g deployer mfec
echo "mfec:p@ssw0rds" | sudo chpasswd
sudo useradd -m -g deployer gp6
echo "gp6:p@ssw6rd" | sudo chpasswd
sudo useradd -m -g deployer gp7
echo "gp7:p@ssw7rd" | sudo chpasswd
sudo useradd -m -g deployer gp8
echo "gp8:p@ssw8rd" | sudo chpasswd
sudo useradd -m -g deployer gp9
echo "gp9:p@ssw9rd" | sudo chpasswd
sudo useradd -m -g deployer gp10
echo "gp10:p@ssw10rd" | sudo chpasswd

# SSH to center
ssh <user>@<url>

# Clone github
git clone https://github.com/streaming-dev-lab/rag-ecommerce-master.git

# cd to dir
cd rag-ecommerce-master

# Create ssh key and do not input anything just enter (optional)
ssh-keygen -t rsa -b 4096

# config prop
AWS_REGION=ap-southeast-1
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
SSH_PUB_KEY_FILE=~/.ssh/id_rsa.pub
VM_OWNER=mfec
MYSQL_ROOT_PASSWORD=P@ssw0rd
MYSQL_PASSWORD=P@ssw0rd
CONFLUENT_CLOUD_API_KEY=
CONFLUENT_CLOUD_API_SECRET=
CONFLUENT_CLOUD_REGION=$AWS_REGION
CONFLUENT_CLOUD_PROVIDER=AWS
CONFLUENT_CLOUD_ENVIRONMENT=mfec
OPENAI_API_KEY=

# Export path TODO## Export global
export CONFIG_FILE=~/rag-ecommerce-master/config_aws.properties

# Change mod 
chmod +x aws_setup.sh aws_teardown.sh init-scripts/post-init.sh configured_group.sh

# Run config group
~/rag-ecommerce-master/configured_group.sh

# run aws_setup.sh
~/rag-ecommerce-master/aws_setup.sh