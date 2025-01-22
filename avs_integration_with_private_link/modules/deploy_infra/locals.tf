locals {  
    
  sddc_cidr = "172.${tostring(tonumber(var.sddc.sddc_number) + 15)}.0.0/22"
  vnet_cidr = ["172.${tostring(tonumber(var.sddc.sddc_number) + 15)}.12.0/22"]
  vwan_cidr = "172.${tostring(tonumber(var.sddc.sddc_number) + 15)}.24.0/22"
}
