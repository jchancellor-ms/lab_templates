locals {
  ldap_user_name        = "ldapuser"
  test_admin_group_name = "vcenterAdmins"
  test_admin_user_name  = "${var.sddc.domain_prefix}admin"
  domain_distinguished_name        = "dc=${var.sddc.domain_prefix},dc=local"
  domain_fqdn      = "${var.sddc.domain_prefix}.local"
  domain_netbios_name   = "${var.sddc.domain_prefix}"

  tags = {}

  
}




