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
  default = "centos8-cis-l2"
}

# CentOS 8 is end-of-life; pin the base image explicitly if the filter below
# no longer matches anything in your region.
variable "source_ami_name" {
  type    = string
  default = "CentOS 8*x86_64*"
}

locals {
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())
}

source "amazon-ebs" "centos8" {
  region        = var.region
  instance_type = var.instance_type
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
  ssh_username  = "centos"

  source_ami_filter {
    filters = {
      name                = var.source_ami_name
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["125523088429"] # CentOS project
    most_recent = true
  }

  tags = {
    Name      = "${var.ami_prefix}-${local.timestamp}"
    OS        = "CentOS 8"
    Benchmark = "CIS RHEL 8 Level 2 Server"
  }
}

build {
  sources = ["source.amazon-ebs.centos8"]

  # CentOS 8 mirrors were retired at EOL; point dnf at the vault so the
  # playbook can still install packages (aide, firewalld, etc.).
  provisioner "shell" {
    inline = [
      "sudo sed -i -e 's|^mirrorlist=|#mirrorlist=|g' -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo",
      "sudo dnf -y makecache",
    ]
  }

  # Runs from the build machine over SSH, so Ansible is never installed in the image.
  provisioner "ansible" {
    playbook_file   = "${path.root}/playbook.yml"
    galaxy_file     = "${path.root}/../requirements.yml"
    user            = "centos"
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
