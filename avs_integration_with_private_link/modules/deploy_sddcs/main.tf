//cerate naming and resource group resources
resource "random_string" "name_suffix" {  
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  location = var.sddc.location
  name     = "${var.sddc.name_prefix}-rg-sddc-${random_string.name_suffix.result}"

  lifecycle {
    ignore_changes = [tags]
  }
}

module "test_private_cloud" {
  #source = "../../"
  source             = "Azure/avm-res-avs-privatecloud/azurerm"
  version            = "=0.8.2"

  enable_telemetry           = true
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  resource_group_resource_id = azurerm_resource_group.this.id
  name                       = "${var.sddc.name_prefix}-avs-${random_string.name_suffix.result}"
  sku_name                   = var.sddc.avs_sku
  avs_network_cidr           = var.sddc.avs_network_cidr
  internet_enabled           = false
  management_cluster_size    = 4

  dhcp_configuration = {
    server_config = {
      display_name      = "test_dhcp"
      dhcp_type         = "SERVER"
      server_lease_time = 14400
      server_address    = local.dhcp_cidr
    }
  }

  diagnostic_settings = {
    avs_diags = {
      name                  = "${var.sddc.name_prefix}-avs-${random_string.name_suffix.result}-diags"
      workspace_resource_id = var.log_analytics_workspace_resource_id
      metric_categories     = ["AllMetrics"]
      log_groups            = ["allLogs"]
    }
  }

  dns_forwarder_zones = {
    ignite_local = {
      display_name               = local.domain_netbios_name
      dns_server_ips             = var.dns_server_ips
      domain_names               = [local.domain_fqdn]
      add_to_default_dns_service = true
    }
  }

  expressroute_connections = {
    default = {
      name                             = "${var.sddc.name_prefix}-avs-${random_string.name_suffix.result}-connection"
      vwan_hub_connection              = true
      expressroute_gateway_resource_id = var.expressroute_gateway_resource_id
      authorization_key_name           = "${var.sddc.name_prefix}-avs-${random_string.name_suffix.result}-auth-key"
    }
  }

  segments = local.segment_defs

  vcenter_identity_sources = {
    ignite_local = {
      alias          = local.domain_netbios_name
      base_group_dn  = local.domain_distinguished_name
      base_user_dn   = local.domain_distinguished_name
      domain         = local.domain_fqdn
      group_name     = "vcenterAdmins"
      name           = local.domain_fqdn
      primary_server = "ldaps://${var.dc1_hostname}.${local.domain_fqdn}:636"
      secondary_server = "ldaps://${var.dc2_hostname}.${local.domain_fqdn}:636"
      ssl = "Enabled"
    }
  }

  vcenter_identity_sources_credentials = {
    ignite_local = {
      ldap_user          = var.ldap_user_name
      ldap_user_password = var.ldap_user_password
    }
  }

}
