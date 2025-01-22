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

variable "is_skillable" {
  description = "Flag to determine if the deployment is hosted on skillable where we don't have permissions to do RBAC"
  type = bool
  default = true  
}