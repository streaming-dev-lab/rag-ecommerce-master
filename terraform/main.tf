

provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  default_tags{
    tags = {
  	Owner = var.aws_owner
    }
  }
}


resource "random_id" "id" {
  byte_length = 4
}

data "aws_vpc" "default"{
  default = true
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name = "default"
}



resource "aws_key_pair" "pub_key" {
  key_name = "pub_${random_id.id.id}"
  public_key = file("${pathexpand(var.public_key_file_path)}")
}

data "aws_ami" "amzn_lnx" {
  name_regex = "amzn2-ami-kernel-5.10*"
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "architecture"
    values = ["x86_64"]
  }

  filter {
    name = "owner-alias"
    values = ["amazon"]
  }
}

resource "aws_security_group" "allow_traffic" {
  name = "allow_ssh_${random_id.id.id}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8001
    to_port = 8001
    protocol = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8501
    to_port = 8501
    protocol = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

}

resource "aws_instance" "bastion" {
  ami = data.aws_ami.amzn_lnx.id
  instance_type = "t3.large"
  associate_public_ip_address = true
 
  vpc_security_group_ids = [
    aws_security_group.allow_traffic.id,
    data.aws_security_group.default.id
  ]
  key_name = aws_key_pair.pub_key.key_name

  root_block_device {
    volume_size = 20
  }

  user_data = <<EOF
#!/usr/bin/env bash

sudo yum install -y docker 
sudo systemctl start docker
sudo usermod -a -G docker ec2-user

EOF

  lifecycle {
    ignore_changes = [
      security_groups
    ]
  }
  tags = {
    Name = "bastion"
  }
}

/*
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw_${random_id.id.id}"
  }
}
*/

/*
resource "aws_route" "gw" {
  route_table_id            = aws_vpc.main.main_route_table_id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id
}
*/

resource "local_file" "ip_bastion" {
  filename = "./tmp/commerce_bastion_ip.txt"
  content  = aws_instance.bastion.public_ip
}
