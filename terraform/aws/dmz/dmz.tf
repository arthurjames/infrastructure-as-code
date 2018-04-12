terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

locals {
  env_name = "dmz"
}

data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "${path.module}/../vars/terraform.tfstate"
  }
}

provider "aws" {
  region = "${data.terraform_remote_state.global.region}"
}

resource "aws_eip" "nat_bastion" {
  count = "${data.terraform_remote_state.global.elastic_ips["dmz"]}"
  vpc   = true
}

########################################
# VPC: dmz
########################################
module "vpc_dmz" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "${upper(local.env_name)}"

  azs                  = "${data.terraform_remote_state.global.availability_zones}"
  cidr                 = "${data.terraform_remote_state.global.vpc_cidrs["bastion"]}"
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  external_nat_ip_ids  = ["${aws_eip.nat_bastion.*.id}"]
  private_subnets      = []
  public_subnets       = ["${data.terraform_remote_state.global.public_subnets["bastion"]}"]

  tags = {
    Terraform   = "true"
    Environment = "P"
  }
}

########################################
# EC2-INSTANCE: bastion
########################################
module "node_bastion" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "${local.env_name}-bastion"

  ami                         = "${lookup(data.terraform_remote_state.global.amis, data.terraform_remote_state.global.region)}"
  associate_public_ip_address = true
  instance_type               = "${lookup(data.terraform_remote_state.global.instance_types, "bastion")}"
  key_name                    = "${data.terraform_remote_state.global.key_name}"
  monitoring                  = false
  subnet_id                   = "${element(module.vpc_dmz.public_subnets,0)}"
  vpc_security_group_ids      = ["${module.sg_bastion.this_security_group_id}"]

  tags = {
    Terraform       = "true"
    Environment     = "P"
    ansibleNodeType = "bastion"
  }
}

########################################
# SECURITY-GROUP: bastion-sg
########################################
module "sg_bastion" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "sg_bastion"

  description = "Security group for bastion nodes"
  vpc_id      = "${module.vpc_dmz.vpc_id}"

  ingress_cidr_blocks = ["${lookup(data.terraform_remote_state.global.ingress_with_cidr_blocks_map, "dmz-public-ssh")}"]
  ingress_rules       = ["ssh-tcp"]

  egress_with_cidr_blocks = [{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = "0.0.0.0/0"
  }]

  tags = {
    Terraform   = "true"
    Environment = "P"
  }
}
