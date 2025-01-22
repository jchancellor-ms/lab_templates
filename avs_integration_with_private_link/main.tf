#run vm sku finder utility with caching
#run avs sku finder utility with caching
#call the module to deploy the sddc artifacts

module "deploy_infra" {
  for_each = var.sddcs

  source = "./modules/deploy_infra"
  sddc   = each.value
}

module "vm_skus" {
  for_each = var.sddcs
  source   = "Azure/avm-utl-sku-finder/azapi"
  version  = "0.3.0"

  enable_telemetry = true
  location         = each.value.location
  resource_type    = "vm"
  vm_filters = {
    accelerated_networking_enabled = true
    cpu_architecture_type          = "x64"
    min_vcpus                      = 2
    max_vcpus                      = 2
    encryption_at_host_supported   = true
    min_network_interfaces         = 2
  }

  cache_results      = true
  local_cache_prefix = each.value.name_prefix

}

#deploy the domain controllers with bastion
module "create_dc" {
  for_each = var.sddcs
  source   = "./modules/domain_controllers"

  sddc                        = each.value
  dc_vm_sku                   = module.vm_skus[each.key].sku
  virtual_network_resource_id = module.deploy_infra[each.key].vnet_id
  dc_subnet_resource_id       = module.deploy_infra[each.key].dc_subnet_id
  bastion_subnet_resource_id  = module.deploy_infra[each.key].bastion_subnet_id
  dc_subnet_cidr              = module.deploy_infra[each.key].dc_subnet_cidr
  key_vault_resource_id       = module.deploy_infra[each.key].key_vault_resource_id

  depends_on = [ module.deploy_infra ]
}

/*
module "deploy_sddcs" {
  for_each = var.sddcs

  source                              = "./modules/deploy_sddcs"
  sddc                                = each.value
  ldap_user_name                      = module.create_dc[each.key].ldap_user_name
  ldap_user_password                  = module.create_dc[each.key].ldap_password
  log_analytics_workspace_resource_id = module.deploy_infra[each.key].log_analytics_resource_id
  dns_server_ips                      = module.create_dc[each.key].dns_server_ips
  expressroute_gateway_resource_id    = module.deploy_infra[each.key].expressroute_gateway_resource_id
  dc1_hostname                        = module.create_dc[each.key].dc_details.name
  dc2_hostname                        = module.create_dc[each.key].dc_details_secondary.name
}
*/

