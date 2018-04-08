output "acl_id" {
  value = "${module.vpc_ims.default_network_acl_id}"
}

output "vpc_id" {
  value = "${module.vpc_ims.vpc_id}"
}

output "vpc_cidr_block" {
  value = "${module.vpc_ims.vpc_cidr_block}"
}

output "private_route_table_id" {
  value = "${element(module.vpc_ims.private_route_table_ids,0)}"
}

output "public_route_table_id" {
  value = "${element(module.vpc_ims.public_route_table_ids,0)}"
}
