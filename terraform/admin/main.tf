provider "aws" {
  region = "${var.region}"
}

data aws_ami "hashistack" {
  most_recent = true
  owners      = ["self"]
  name_regex  = "hashistack-image-.*"
}

resource "aws_key_pair" "main" {
  key_name   = "${var.ssh_key_name}"
  public_key = "${var.public_key_data}"
}

resource "aws_instance" "admin" {
  ami               = "${data.aws_ami.hashistack.id}"
  instance_type     = "t2.micro"
  count             = 1
  subnet_id         = "${var.subnet_ids[0]}"
  key_name          = "${var.ssh_key_name}"
  source_dest_check = "false"

  security_groups = [
    "${aws_security_group.allow_all_admin.id}",
  ]

  associate_public_ip_address = true
  ebs_optimized               = false
  iam_instance_profile        = "${var.instance_profile}"

  provisioner "file" {
    source      = "${path.module}/nomad"
    destination = "/home/ubuntu"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${var.private_key_data}"
    }
  }

  tags {
    Environment-Name = "${var.environment_name}"
    role             = "admin"
    owner            = "${var.owner}"
    TTL              = "${var.ttl}"
  }

  user_data = "${data.template_file.admin.rendered}"
}

data "template_file" "admin" {
  template = "${file("${path.module}/init-admin.tpl")}"

  vars = {
    environment_name = "${var.environment_name}"
    local_region     = "${var.region}"
    private_key      = "${var.private_key_data}"
  }
}

data "template_file" "format_ssh" {
  template = "connect to host with following command: ssh ubuntu@$${admin} -i private_key.pem"

  vars {
    admin = "${aws_instance.admin.public_ip}"
  }
}

resource "aws_security_group" "allow_all_admin" {
  name        = "allow_all_admin"
  description = "Allow all admin"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}