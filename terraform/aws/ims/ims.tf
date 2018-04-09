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

########################################
# VPC: ims
########################################
module "vpc_ims" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "IMS"

  azs                  = "${data.terraform_remote_state.global.availability_zones}"
  cidr                 = "${data.terraform_remote_state.global.vpc_cidrs["ims"]}"
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  private_subnets      = ["${data.terraform_remote_state.global.private_subnets["ims"]}"]
  public_subnets       = ["${data.terraform_remote_state.global.public_subnets["ims"]}"]

  tags = {
    Terraform   = "true"
    Environment = "P"
  }
}

########################################
# EC2-INSTANCE: nginx proxy with grafana
########################################
module "node_nginx" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "grafana"

  ami                         = "${lookup(data.terraform_remote_state.global.amis, data.terraform_remote_state.global.region)}"
  associate_public_ip_address = true
  instance_type               = "${lookup(data.terraform_remote_state.global.instance_types, "nginx")}"
  key_name                    = "${data.terraform_remote_state.global.key_name}"
  monitoring                  = false
  subnet_id                   = "${element(module.vpc_ims.public_subnets,0)}"

  vpc_security_group_ids = [
    "${module.sg_ims_ssh.this_security_group_id}",
    "${module.sg_ims_public_nginx.this_security_group_id}",
  ]

  tags = {
    Terraform       = "true"
    Environment     = "P"
    ansibleNodeType = "grafana"
  }
}

########################################
# EC2-INSTANCE: jenkins
########################################
module "node_jenkins" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "jenkins"

  ami                         = "${lookup(data.terraform_remote_state.global.amis, data.terraform_remote_state.global.region)}"
  associate_public_ip_address = true
  instance_type               = "${lookup(data.terraform_remote_state.global.instance_types, "jenkins")}"
  key_name                    = "${data.terraform_remote_state.global.key_name}"
  monitoring                  = false
  subnet_id                   = "${element(module.vpc_ims.private_subnets,0)}"

  vpc_security_group_ids = [
    "${module.sg_ims_ssh.this_security_group_id}",
    "${module.sg_ims_private_jenkins.this_security_group_id}",
  ]

  tags = {
    Terraform       = "true"
    Environment     = "P"
    ansibleNodeType = "jenkins"
  }
}

########################################
# EC2-INSTANCE: elastic
########################################
module "node_elastic" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "elastic"

  ami                         = "${lookup(data.terraform_remote_state.global.amis, data.terraform_remote_state.global.region)}"
  associate_public_ip_address = true
  instance_type               = "${lookup(data.terraform_remote_state.global.instance_types, "elastic")}"
  key_name                    = "${data.terraform_remote_state.global.key_name}"
  monitoring                  = false
  subnet_id                   = "${element(module.vpc_ims.private_subnets,0)}"

  vpc_security_group_ids = [
    "${module.sg_ims_ssh.this_security_group_id}",
    "${module.sg_ims_private_elastic.this_security_group_id}",
  ]

  tags = {
    Terraform       = "true"
    Environment     = "P"
    ansibleNodeType = "elastic"
  }
}

########################################
# EC2-INSTANCE: prometheus
########################################
module "node_prometheus" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "prometheus"

  ami                         = "${lookup(data.terraform_remote_state.global.amis, data.terraform_remote_state.global.region)}"
  associate_public_ip_address = true
  instance_type               = "${lookup(data.terraform_remote_state.global.instance_types, "prometheus")}"
  key_name                    = "${data.terraform_remote_state.global.key_name}"
  monitoring                  = false
  subnet_id                   = "${element(module.vpc_ims.private_subnets,0)}"

  vpc_security_group_ids = [
    "${module.sg_ims_ssh.this_security_group_id}",
    "${module.sg_ims_private_prometheus.this_security_group_id}",
  ]

  tags = {
    Terraform       = "true"
    Environment     = "P"
    ansibleNodeType = "prometheus"
  }
}

########################################
# SECURITY-GROUP: sg_ims_ssh
########################################
module "sg_ims_ssh" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "sg_ims_ssh"

  description = "Security group for ssh access on ims vpc"
  vpc_id      = "${module.vpc_ims.vpc_id}"

  ingress_cidr_blocks = ["${lookup(data.terraform_remote_state.global.ingress_with_cidr_blocks_map, "ims-ssh")}"]

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
# SECURITY-GROUP: sg_ims_public_nginx
########################################
module "sg_ims_public_nginx" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "sg_ims_public_nginx"

  description = "Security group for nginx nodes on public ims"
  vpc_id      = "${module.vpc_ims.vpc_id}"

  ingress_cidr_blocks = ["${lookup(data.terraform_remote_state.global.ingress_with_cidr_blocks_map, "ims-public-http")}"]

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

########################################
# SECURITY-GROUP: sg_ims_private_jenkins
########################################
module "sg_ims_private_jenkins" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "sg_ims_private_jenkins"

  description = "Security group for jenkins host on ims private subnet"
  vpc_id      = "${module.vpc_ims.vpc_id}"

  ingress_cidr_blocks = ["${lookup(data.terraform_remote_state.global.ingress_with_cidr_blocks_map, "ims-private")}"]

  ingress_rules = [
    "http-8080-tcp",
    "https-443-tcp",
  ]

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
# SECURITY-GROUP: sg_ims_private_elastic
########################################
module "sg_ims_private_elastic" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "sg_ims_private_elastic"

  description = "Security group for elastic host on ims private subnet"
  vpc_id      = "${module.vpc_ims.vpc_id}"

  ingress_cidr_blocks = ["${lookup(data.terraform_remote_state.global.ingress_with_cidr_blocks_map, "ims-private")}"]

  ingress_rules = [
    "elasticsearch-rest-tcp",
    "elasticsearch-java-tcp",
  ]

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
# SECURITY-GROUP: sg_ims_private_prometheus
########################################
module "sg_ims_private_prometheus" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "sg_ims_private_prometheus"

  description = "Security group for prometheus host on ims private subnet"
  vpc_id      = "${module.vpc_ims.vpc_id}"

  ingress_with_cidr_blocks = [{
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = "${lookup(data.terraform_remote_state.global.ingress_with_cidr_blocks_map, "ims-private")}"
  }]

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
