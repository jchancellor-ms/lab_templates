variable "sddcs" {
  description = "The index to use for the SDDC deployment artificats"
  type = map(object({
    sddc_number   = number
    name_prefix   = string
    location      = string
    dc_vm_sku     = optional(string)
    avs_sku       = optional(string)
    domain_prefix = string
  }))
}

variable "dc_vm_sku" {
  description = "The SKU to use for the DC VMs if using the utility to generate.  Otherwise, set the sku in the sddc object"
  type = string  
  default = null
}

variable "avs_sku" {
  description = "The SKU to use for the AVS if using the utility to generate.  Otherwise, set the sku in the sddc object"
  type = string  
  default = null  
}