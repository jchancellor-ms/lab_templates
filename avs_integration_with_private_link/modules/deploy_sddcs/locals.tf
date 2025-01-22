locals {

  ldap_user_name            = "ldapuser"
  test_admin_group_name     = "vcenterAdmins"
  test_admin_user_name      = "${var.sddc.domain_prefix}admin"
  domain_distinguished_name = "dc=${var.sddc.domain_prefix},dc=local"
  domain_fqdn               = "${var.sddc.domain_prefix}.local"
  domain_netbios_name       = var.sddc.domain_prefix

  sddc_cidr = "172.${tostring(tonumber(var.sddc.sddc_number) + 15)}.0.0/22"
  vnet_cidr = ["172.${tostring(tonumber(var.sddc.sddc_number) + 15)}.12.0/22"]
  vwan_cidr = "172.${tostring(tonumber(var.sddc.sddc_number) + 15)}.24.0/22"
  dhcp_cidr = "172.${tostring(tonumber(var.sddc.sddc_number) + 15)}.32.1/24"

  segment_defs = { for value in range(1, 250) : "segment_${value}" => {
    display_name    = "lab_segment_${value}"
    gateway_address = "192.168.${value}.1/24"
    dhcp_ranges     = ["192.168.${value}.5-192.168.${value}.50"]
    }
  }
}
