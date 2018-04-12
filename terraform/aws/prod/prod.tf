terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "${path.module}/../vars/terraform.tfstate"
  }
}

provider "aws" {
  region  = "${data.terraform_remote_state.global.region}"
  version = "~> 1.14"
}

locals {
  env_name = "prod"
}

########################################
# VPC: prod
########################################
module "vpc_prod" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "${upper(local.env_name)}"

  azs                  = "${data.terraform_remote_state.global.availability_zones}"
  cidr                 = "${data.terraform_remote_state.global.vpc_cidrs["prod"]}"
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  private_subnets      = ["${data.terraform_remote_state.global.private_subnets["prod"]}"]
  public_subnets       = ["${data.terraform_remote_state.global.public_subnets["prod"]}"]

  tags = {
    Terraform   = "true"
    Environment = "P"
  }
}

########################################
# EC2-INSTANCE: nginx proxy
########################################
module "node_nginx" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "${local.env_name}-nginx"

  ami                         = "${lookup(data.terraform_remote_state.global.amis, data.terraform_remote_state.global.region)}"
  associate_public_ip_address = true
  instance_type               = "${lookup(data.terraform_remote_state.global.instance_types, "nginx")}"
  key_name                    = "${data.terraform_remote_state.global.key_name}"
  monitoring                  = false
  subnet_id                   = "${element(module.vpc_prod.public_subnets,0)}"

  vpc_security_group_ids = [
    "${module.sg_prod_ssh.this_security_group_id}",
    "${module.sg_prod_public_nginx.this_security_group_id}",
  ]

  tags = {
    Terraform       = "true"
    Environment     = "P"
    ansibleNodeType = "nginx"
  }
}

########################################
# EC2-INSTANCE: k8s-master
########################################
module "node_k8s_master" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "${local.env_name}-k8s-master"

  ami                         = "${lookup(data.terraform_remote_state.global.amis, data.terraform_remote_state.global.region)}"
  associate_public_ip_address = true
  instance_type               = "${lookup(data.terraform_remote_state.global.instance_types, "k8s-master")}"
  key_name                    = "${data.terraform_remote_state.global.key_name}"
  monitoring                  = false
  subnet_id                   = "${element(module.vpc_prod.private_subnets,0)}"

  vpc_security_group_ids = [
    "${module.sg_prod_ssh.this_security_group_id}",
    "${module.sg_prod_private_k8s.this_security_group_id}",
  ]

  tags = {
    Terraform       = "true"
    Environment     = "P"
    ansibleNodeType = "k8s-master"
  }
}

########################################
# EC2-INSTANCE: k8s-minion-1
########################################
module "node_k8s_minion_1" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "${local.env_name}-k8s-minion-1"

  ami                         = "${lookup(data.terraform_remote_state.global.amis, data.terraform_remote_state.global.region)}"
  associate_public_ip_address = true
  instance_type               = "${lookup(data.terraform_remote_state.global.instance_types, "k8s-minion")}"
  key_name                    = "${data.terraform_remote_state.global.key_name}"
  monitoring                  = false
  subnet_id                   = "${element(module.vpc_prod.private_subnets,0)}"

  vpc_security_group_ids = [
    "${module.sg_prod_ssh.this_security_group_id}",
    "${module.sg_prod_private_k8s.this_security_group_id}",
  ]

  tags = {
    Terraform       = "true"
    Environment     = "P"
    ansibleNodeType = "k8s-minion"
  }
}

########################################
# EC2-INSTANCE: k8s-minion-2
########################################
module "node_k8s_minion_2" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "${local.env_name}-k8s-minion-2"

  ami                         = "${lookup(data.terraform_remote_state.global.amis, data.terraform_remote_state.global.region)}"
  associate_public_ip_address = true
  instance_type               = "${lookup(data.terraform_remote_state.global.instance_types, "k8s-minion")}"
  key_name                    = "${data.terraform_remote_state.global.key_name}"
  monitoring                  = false
  subnet_id                   = "${element(module.vpc_prod.private_subnets,0)}"

  vpc_security_group_ids = [
    "${module.sg_prod_ssh.this_security_group_id}",
    "${module.sg_prod_private_k8s.this_security_group_id}",
  ]

  tags = {
    Terraform       = "true"
    Environment     = "P"
    ansibleNodeType = "k8s-minion"
  }
}

########################################
# SECURITY-GROUP: sg_prod_ssh
########################################
module "sg_prod_ssh" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "sg_prod_ssh"

  description = "Security group for ssh access on prod vpc"
  vpc_id      = "${module.vpc_prod.vpc_id}"

  ingress_cidr_blocks = ["${lookup(data.terraform_remote_state.global.ingress_with_cidr_blocks_map, "prod-ssh")}"]

  ingress_rules = ["ssh-tcp"]

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

########################################
# SECURITY-GROUP: sg_prod_private_k8s
########################################
module "sg_prod_private_k8s" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "sg_prod_private_k8s"

  description = "Security group for k8s hosts on prod private subnet"
  vpc_id      = "${module.vpc_prod.vpc_id}"

  ingress_cidr_blocks = ["${lookup(data.terraform_remote_state.global.ingress_with_cidr_blocks_map, "prod-private")}"]

  ingress_rules = ["https-443-tcp"]

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

########################################
# SECURITY-GROUP: sg_prod_public_nginx
########################################
module "sg_prod_public_nginx" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "sg_prod_public_nginx"

  description = "Security group for nginx nodes on public prod"
  vpc_id      = "${module.vpc_prod.vpc_id}"

  ingress_cidr_blocks = ["${lookup(data.terraform_remote_state.global.ingress_with_cidr_blocks_map, "prod-public-http")}"]

  ingress_rules = ["http-80-tcp", "https-443-tcp"]

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
