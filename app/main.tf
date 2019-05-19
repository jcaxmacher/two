variable "private_key" {
  default = "c:/Users/jeremy/.ssh/jca-us-east-1.pem"
}

provider "aws" {
  region                  = "us-east-1"
  version = "2.10"
}

provider "http" {
  version = "1.1"
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

data "aws_ami" "amzn_linux" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*x86_64-ebs"]
  }

  owners = ["137112412989"]
}

resource "aws_instance" "nginx1" {
  ami                         = "${data.aws_ami.amzn_linux.id}"
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  key_name                    = "jca-us-east-1"

  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = "${file(var.private_key)}"
  }

  provisioner "remote-exec" {
    inline = [
    "sudo amazon-linux-extras install -y nginx1.12",
    "sudo systemctl start nginx.service",
      "echo '<html><head><title>Blue team server</title></head><body style=\"background-color: blue\"></body></html>' | sudo tee /usr/share/nginx/html/index.html"
    ]
  }
}

output "aws_instance_public_dns" {
    value = "${aws_instance.nginx1.public_dns}"
}