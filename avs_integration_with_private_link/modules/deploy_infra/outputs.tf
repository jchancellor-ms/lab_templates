output "vnet_id" {
  description = "The ID of the virtual network created by the module."
  value       = module.vm_vnet.resource_id
}

output "dc_subnet_id" {
  description = "The ID of the subnet created by the module."
  value       = module.vm_vnet.subnets["DCSubnet"].resource_id  
}

output "bastion_subnet_id" {
  description = "The ID of the subnet created by the module."
  value       = module.vm_vnet.subnets["AzureBastionSubnet"].resource_id  
}

output "dc_subnet_cidr" {
  description = "The CIDR of the subnet created by the module."
  value       = cidrsubnet(local.vnet_cidr[0], 2, 0)
}

output "key_vault_resource_id" {
    description = "The resource ID of the key vault where the secrets are stored."
    value       = var.is_skillable ? azurerm_key_vault.this[0].id : try(module.avm_res_keyvault_vault[0].resource_id, null) 
}

output "log_analytics_resource_id" {
  description = "The ID of the log analytics workspace created by the module."
  value       = azurerm_log_analytics_workspace.this_workspace.id
}

/*
output "expressroute_gateway_resource_id" {
  description = "The ID of the expressroute gateway created by the module."
  value       = module.vwan_with_vhub.expressroute-gateway.resource_id
}
*/