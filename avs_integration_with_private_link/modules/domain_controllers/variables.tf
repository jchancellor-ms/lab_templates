variable "sddc" {
  description = "The index to use for the SDDC deployment artifacts"
  type = object({
    sddc_number   = number
    name_prefix   = string
    location      = string
    dc_vm_sku     = optional(string)
    avs_sku       = optional(string)
    domain_prefix = string
  })
}

variable "dc_vm_sku" {
  description = "The SKU to use for the DC VMs if using the utility to generate.  Otherwise, set the sku in the sddc object"
  type = string  
  default = null
}

variable "dc_dsc_script_url" {
  type        = string
  default     = "https://raw.githubusercontent.com/Azure/terraform-azurerm-avm-res-avs-privatecloud/main/modules/create_test_domain_controllers/templates/dc_windows_dsc.ps1"
  description = "the github url for the raw DSC configuration script that will be used by the custom script extension."
}

variable "dc_dsc_script_url_secondary" {
  type        = string
  default     = "https://raw.githubusercontent.com/Azure/terraform-azurerm-avm-res-avs-privatecloud/main/modules/create_test_domain_controllers/templates/dc_secondary_windows_dsc.ps1"
  description = "the github url for the raw DSC configuration script that will be used by the custom script extension."
}

variable "virtual_network_resource_id" {
  type        = string
  description = "The resource ID Of the virtual network where the resources are deployed."
}

variable "dc_subnet_resource_id" {
  type        = string
  description = "The Azure Resource ID for the subnet where the DC will be connected."
}

variable "bastion_subnet_resource_id" {
  type        = string
  default     = null
  description = "The Azure Resource ID for the subnet where the bastion will be connected."
}

variable "dc_subnet_cidr" {
  type = string
  description = "value for the DC subnet cidr"
}

variable "key_vault_resource_id" {
  type        = string
  description = "The resource ID of the key vault where the secrets are stored." 
}

variable "is_skillable" {
  description = "Flag to determine if the deployment is hosted on skillable where we don't have permissions to do RBAC"
  type = bool
  default = true   
}