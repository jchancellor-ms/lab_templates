//cerate naming and resource group resources
resource "random_string" "name_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  location = var.sddc.location
  name     = "${var.sddc.name_prefix}-rg-${random_string.name_suffix.result}"

  lifecycle {
    ignore_changes = [tags]
  }
}

# deploy a nat gateway for dc internet access
module "natgateway" {
  source  = "Azure/avm-res-network-natgateway/azurerm"
  version = "0.2.1"

  name                = "${var.sddc.name_prefix}-nat-gw-${random_string.name_suffix.result}"
  enable_telemetry    = true
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  zones               = null

  public_ip_configuration = {
    zones = []
  }

  public_ips = {
    public_ip_1 = {
      name = "${var.sddc.name_prefix}-nat-gw-pip-1-${random_string.name_suffix.result}"
    }
  }
}

#deploy a vnet for bastion and domain controllers
module "vm_vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "=0.7.1"

  resource_group_name = azurerm_resource_group.this.name
  address_space       = local.vnet_cidr
  name                = "${var.sddc.name_prefix}-vnet--${random_string.name_suffix.result}"
  location            = azurerm_resource_group.this.location

  subnets = {
    DCSubnet = {
      name             = "DCSubnet"
      address_prefixes = [cidrsubnet(local.vnet_cidr[0], 2, 0)]
      nat_gateway = {
        id = module.natgateway.resource_id
      }
    }
    AzureBastionSubnet = {
      name             = "AzureBastionSubnet"
      address_prefixes = [cidrsubnet(local.vnet_cidr[0], 2, 1)]
    }
  }
}

#deploy log analytics
resource "azurerm_log_analytics_workspace" "this_workspace" {
  name                = "${var.sddc.name_prefix}-law-${random_string.name_suffix.result}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

#deploy the vwan secure hub with routing intent and expressRoute gateway
module "vwan_with_vhub" {
  source  = "Azure/avm-ptn-virtualwan/azurerm"
  version = "0.8.0"

  create_resource_group          = false
  resource_group_name            = azurerm_resource_group.this.name
  location                       = azurerm_resource_group.this.location
  virtual_wan_name               = "${var.sddc.name_prefix}-vwan-${random_string.name_suffix.result}"
  disable_vpn_encryption         = false
  allow_branch_to_branch_traffic = true
  type                           = "Standard"

  #deploy the vwan hub
  virtual_hubs = {
    "${var.sddc.name_prefix}-vhub" = {
      name           = "${var.sddc.name_prefix}-vhub-${random_string.name_suffix.result}"
      location       = azurerm_resource_group.this.location
      resource_group = azurerm_resource_group.this.name
      address_prefix = "10.0.${tostring(var.sddc.sddc_number)}.0/24"
    }
  }

  #deploy the expressRoute gateway
  expressroute_gateways = {
    "${var.sddc.name_prefix}-ergw" = {
      name            = "${var.sddc.name_prefix}-ergw-${random_string.name_suffix.result}"
      virtual_hub_key = "${var.sddc.name_prefix}-vhub"
      scale_units     = 1
    }
  }

  #deploy the azfw
  firewalls = {
    "${var.sddc.name_prefix}-azfw" = {
      sku_name        = "AZFW_Hub"
      sku_tier        = "Standard"
      name            = "${var.sddc.name_prefix}-azfw-${random_string.name_suffix.result}"
      virtual_hub_key = "${var.sddc.name_prefix}-vhub"
    }
  }

  #configure routing intent
  routing_intents = {
    "${var.sddc.name_prefix}-vhub-ri" = {
      name            = "${var.sddc.name_prefix}-vhub-ri-${random_string.name_suffix.result}"
      virtual_hub_key = "${var.sddc.name_prefix}-vhub"
      routing_policies = [{
        name                  = "${var.sddc.name_prefix}-vhub-routing-policy-private-${random_string.name_suffix.result}"
        destinations          = ["PrivateTraffic"]
        next_hop_firewall_key = "${var.sddc.name_prefix}-azfw"
      }]
    }
  }

  #Connect the vnet to the vwan hub
  virtual_network_connections = {
    "${var.sddc.name_prefix}-dc-vnet-conn" = {
      virtual_network_connection_name = "${var.sddc.name_prefix}-dc-vnet-conn-${random_string.name_suffix.result}"
      name                            = "${var.sddc.name_prefix}-dc-vnet-conn-${random_string.name_suffix.result}"
      virtual_hub_key                 = "${var.sddc.name_prefix}-vhub"
      remote_virtual_network_id       = module.vm_vnet.resource_id
      internet_security_enabled       = true
    }
  }
}

data "azurerm_client_config" "current" {}


module "avm_res_keyvault_vault" {
  count = var.is_skillable ? 0 : 1

  source                 = "Azure/avm-res-keyvault-vault/azurerm"
  version                = "0.9.0"
  tenant_id              = data.azurerm_client_config.current.tenant_id
  name                   = "${var.sddc.name_prefix}-kv-${random_string.name_suffix.result}"
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  enabled_for_deployment = true
  network_acls = {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  role_assignments = {
    deployment_user_secrets = {
      role_definition_id_or_name = "Key Vault Administrator"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }

  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }
}

resource "azurerm_key_vault" "this" {
  count = var.is_skillable ? 1 : 0

  name                            = "${var.sddc.name_prefix}-kv${random_string.name_suffix.result}"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  sku_name                        = "standard"
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  enabled_for_deployment          = true
  purge_protection_enabled        = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  enable_rbac_authorization = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = {
    environment = "production"
  }
}

resource "azurerm_key_vault_access_policy" "example" {
  count = var.is_skillable ? 1 : 0

  key_vault_id = azurerm_key_vault.this[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "UnwrapKey", "WrapKey",
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
  ]

  certificate_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore"
  ]
}
