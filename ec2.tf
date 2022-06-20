provider "aws" {
  region     = "us-east-1"
}


resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-gaby"
  }
}




resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "rt-gaby"
  }

}

resource "aws_subnet" "my_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.0.0/24"
  #availability_zone =  "us-east-1"

  tags = {
    Name = "subnet-gaby"
  }
}

resource "aws_route_table_association" "arta" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_network_acl" "my_network_acl" {
  vpc_id = aws_vpc.my_vpc.id

  egress {
    protocol   = -1
    rule_no    = 400
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # ingress {
  #   protocol   = "tcp"
  #   rule_no    = 100
  #   action     = "allow"
  #   cidr_block = "0.0.0.0/0"
  #   from_port  = 80
  #   to_port    = 80
  # }

  # ingress {
  #   protocol   = "tcp"
  #   rule_no    = 200
  #   action     = "allow"
  #   cidr_block = "0.0.0.0/0"
  #   from_port  = 443
  #   to_port    = 443
  # }

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "gaby_network_acl"
  }
}


resource "aws_network_acl_association" "main" {
  network_acl_id = aws_network_acl.my_network_acl.id
  subnet_id      = aws_subnet.my_subnet.id
}

# resource "aws_network_interface" "foo" {
#   subnet_id   = aws_subnet.my_subnet.id
#   #security_groups = ["${aws_security_group.allow_http_https_ssh_internet.id}"]
#   tags = {
#     Name = "primary_network_interface"
#   }
# }

resource "aws_internet_gateway" "gw" {
  tags = {
    Name = "gateway-gab"
  }
}

resource "aws_internet_gateway_attachment" "attache_gw_vpc" {
  internet_gateway_id = aws_internet_gateway.gw.id
  vpc_id              = aws_vpc.my_vpc.id
}



data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


resource "aws_security_group" "allow_http_https_ssh_internet" {
  name        = "gaby-sg"
  description = "Allow http/https inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id
  ingress {
    description = "https from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh from VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "my_ec2" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instancetype
  key_name      = "devops-gaby"
  tags          = var.aws_common_tag
  subnet_id     = aws_subnet.my_subnet.id
  associate_public_ip_address = true
  # network_interface {
  #   network_interface_id = aws_network_interface.foo.id
  #   device_index         = 0
  # }

  root_block_device {
    delete_on_termination = true
  }

  security_groups = ["${aws_security_group.allow_http_https_ssh_internet.id}"]

  provisioner "local-exec" {
    command = "echo \"${aws_instance.my_ec2.public_ip}\n${aws_instance.my_ec2.availability_zone}\n${aws_instance.my_ec2.id}\" > info_ec2.txt"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install -y nginx1.12",
      "sudo systemctl start nginx"
    ]
    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = file("../devops-gaby.pem")
      host = self.public_ip
    }
  }
}
