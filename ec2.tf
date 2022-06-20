provider "aws" {
  region     = "us-east-1"
}

resource "aws_instance" "my_ec2" {
  ami           = "ami-09e26728dcea15e0a"
  instance_type = "t2.micro"
  key_name      = "devops-gaby"
#  tags = {
#    name = "ec2-gaby"
#
#  }
  root_block_device {
    delete_on_termination = true
  }
}
