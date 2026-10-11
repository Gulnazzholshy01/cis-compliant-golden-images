packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.2.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_prefix" {
  type    = string
  default = "ubuntu2204-cis-l1"
}

locals {
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())
}

source "amazon-ebs" "ubuntu2204" {
  region        = var.region
  instance_type = var.instance_type
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
  ssh_username  = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  tags = {
    Name      = "${var.ami_prefix}-${local.timestamp}"
    OS        = "Ubuntu 22.04"
    Benchmark = "CIS Ubuntu 22.04 Level 1 Server"
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu2204"]

  # Let cloud-init finish so apt is not locked when Ansible starts.
  provisioner "shell" {
    inline = [
      "cloud-init status --wait",
      "sudo apt-get update -y",
    ]
  }

  # Runs from the build machine over SSH, so Ansible is never installed in the image.
  provisioner "ansible" {
    playbook_file   = "${path.root}/playbook.yml"
    galaxy_file     = "${path.root}/../requirements.yml"
    user            = "ubuntu"
    use_proxy       = false
    extra_arguments = ["--become"]
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
    ]
  }

  # Generalise the image so each instance gets a fresh identity on first boot.
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs",
      "sudo truncate -s 0 /etc/machine-id",
    ]
  }
}
