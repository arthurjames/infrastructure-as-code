output "acl_id" {
  value = "${module.vpc_prod.default_network_acl_id}"
}

output "vpc_id" {
  value = "${module.vpc_prod.vpc_id}"
}

output "vpc_cidr_block" {
  value = "${module.vpc_prod.vpc_cidr_block}"
}

output "private_route_table_id" {
  value = "${element(module.vpc_prod.private_route_table_ids,0)}"
}

output "public_route_table_id" {
  value = "${element(module.vpc_prod.public_route_table_ids,0)}"
}
