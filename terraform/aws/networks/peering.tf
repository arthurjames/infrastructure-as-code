data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "${path.module}/../vars/terraform.tfstate"
  }
}

provider "aws" {
  region = "${data.terraform_remote_state.global.region}"
}

########################################
# DATA: AWS account
########################################
data "aws_caller_identity" "current" {}

########################################
# DATA: dmz
########################################
data "terraform_remote_state" "dmz" {
  backend = "local"

  config {
    path = "${path.module}/../dmz/terraform.tfstate"
  }
}

########################################
# DATA: ims
########################################
data "terraform_remote_state" "ims" {
  backend = "local"

  config {
    path = "${path.module}/../ims/terraform.tfstate"
  }
}

########################################
# VPC-PEERING-CONNECTION
########################################
resource "aws_vpc_peering_connection" "dmz-ims" {
  peer_owner_id = "${data.aws_caller_identity.current.account_id}"
  peer_vpc_id   = "${data.terraform_remote_state.ims.vpc_id}"
  vpc_id        = "${data.terraform_remote_state.dmz.vpc_id}"
  auto_accept   = true

  tags = {
    Terraform   = "true"
    Environment = "P"
  }
}

########################################
# ROUTES IMS
########################################
resource "aws_route" "dmz-ims" {
  route_table_id            = "${data.terraform_remote_state.dmz.public_route_table_id}"
  destination_cidr_block    = "${data.terraform_remote_state.ims.vpc_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.dmz-ims.id}"
}

resource "aws_route" "ims-dmz-public" {
  route_table_id            = "${data.terraform_remote_state.ims.public_route_table_id}"
  destination_cidr_block    = "${data.terraform_remote_state.dmz.vpc_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.dmz-ims.id}"
}

resource "aws_route" "ims-dmz-private" {
  route_table_id            = "${data.terraform_remote_state.ims.private_route_table_id}"
  destination_cidr_block    = "${data.terraform_remote_state.dmz.vpc_cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.dmz-ims.id}"
}
