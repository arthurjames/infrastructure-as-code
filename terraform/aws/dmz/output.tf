output "acl_id" {
  value = "${module.vpc_dmz.default_network_acl_id}"
}

output "vpc_id" {
  value = "${module.vpc_dmz.vpc_id}"
}

output "vpc_cidr_block" {
  value = "${module.vpc_dmz.vpc_cidr_block}"
}

output "public_route_table_id" {
  value = "${element(module.vpc_dmz.public_route_table_ids,0)}"
}
