variable "funky_town" {
  description = "Somethin funky"
}
variable "private_key" {
  default = "c:/Users/jeremy/.ssh/jca-us-east-1.pem"
}

variable "network_address_space" {
  default  = "10.1.0.0/16"
}

variable "subnet1_address_space" {
  default =   "10.1.0.0/24"
}

variable "subnet2_address_space" {
default =  "10.1.1.0/24"
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

data "aws_availability_zones" "available" {}

resource "aws_vpc" "vpc" {
  cidr_block = "${var.network_address_space}"
  enable_dns_hostnames = "true"
}
  
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_subnet" "subnet1" {
  cidr_block = "${var.subnet1_address_space}"
  vpc_id = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.vpc.id}"
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "rta-subnet1" {
  subnet_id = "${aws_subnet.subnet1.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}

resource "aws_security_group" "nginx-sg" {
  name = "nginx_sg"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "nginx1" {
  ami                         = "${data.aws_ami.amzn_linux.id}"
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  key_name                    = "jca-us-east-1"
  vpc_security_group_ids      = ["${aws_security_group.nginx-sg.id}"]
  subnet_id                   = "${aws_subnet.subnet1.id}"


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