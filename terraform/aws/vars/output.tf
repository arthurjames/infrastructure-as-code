variable "key_name" {
  type = "string"
}

variable "office_cidr" {
  type = "string"
}

locals {
  instance_types = {
    "bastion"    = "t2.nano"
    "elastic"    = "t2.small"
    "jenkins"    = "t2.micro"
    "nginx"      = "t2.nano"
    "prometheus" = "t2.micro"
    "k8s-master" = "t2.nano"
    "k8s-node"   = "t2.nano"
  }

  vpc_cidrs = {
    "bastion" = "10.5.0.0/16"
    "ims"     = "10.6.0.0/16"
    "dev"     = "10.7.0.0/16"
    "prod"    = "10.8.0.0/16"
  }

  public_subnets = {
    "bastion" = "10.5.0.0/24"
    "ims"     = "10.6.1.0/24"
    "dev"     = "10.7.1.0/24"
    "prod"    = "10.8.1.0/24"
  }

  private_subnets = {
    "ims" = "10.6.0.0/24"
    "dev" = "10.7.0.0/24"
    "prd" = "10.8.0.0/24"
  }

  ingress_with_cidr_blocks_map = {
    "dmz-public-ssh"  = "${var.office_cidr}"
    "ims-public-http" = "0.0.0.0/0"
    "ims-ssh"         = "${local.public_subnets["bastion"]}"
    "ims-private"     = "${local.public_subnets["ims"]}"
  }
}

output "amis" {
  value = {
    eu-west-1 = "ami-044b047d"
  }
}

output "availability_zones" {
  value = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

output "ingress_with_cidr_blocks_map" {
  value = "${local.ingress_with_cidr_blocks_map}"
}

output "instance_types" {
  value = "${local.instance_types}"
}

output "key_name" {
  value = "${var.key_name}"
}

output "private_subnets" {
  value = "${local.private_subnets}"
}

output "public_subnets" {
  value = "${local.public_subnets}"
}

output "region" {
  value = "eu-west-1"
}

output "vpc_cidrs" {
  value = "${local.vpc_cidrs}"
}