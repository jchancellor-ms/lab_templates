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

variable "log_analytics_workspace_resource_id" {
  type        = string
  description = "The resource ID of the log analytics workspace where the logs are stored."  
}

variable "dns_server_ips" {
  type        = list(string)
  description = "The list of DNS server IPs to use for the domain controllers."  
}

variable "expressroute_gateway_resource_id" {
  type        = string
  description = "The resource ID of the express route gateway where the private link is connected."   
}

variable "dc1_hostname" { 
  type        = string
  description = "The hostname for the first domain controller."    
}

variable "dc2_hostname" { 
  type        = string
  description = "The hostname for the second domain controller."      
}

variable "ldap_user_name" {
  type        = string
  description = "The username for the LDAP user."    
}

variable "ldap_user_password" {
  type        = string
  description = "The password for the LDAP user."    
  sensitive = true  
}

