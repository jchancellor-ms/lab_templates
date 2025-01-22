resource "azurerm_resource_group" "this" {
  location = var.location
  name     = "${var.name_prefix}-rg-${random_string.name_suffix.result}"

  lifecycle {
    ignore_changes = [tags]
  }
}

data "azurerm_client_config" "current" {}

resource "random_string" "name_suffix" {
  length  = 4
  special = false
  upper   = false
}

module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.4.0"

  name                     = "${var.name_prefix}stgtfstate${random_string.name_suffix.result}"
  location                 = azurerm_resource_group.this.location
  resource_group_name      = azurerm_resource_group.this.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"
  min_tls_version          = "TLS1_2"
  public_network_access_enabled = true
  shared_access_key_enabled     = true
  

  blob_properties = {
    versioning_enabled = true
  }

  containers = {
    tfstate = {
      name = "terraform-state"
      type = "blob"
    }
  }

  role_assignments = {
    blob_owner = {
      role_definition_id_or_name = "Storage Blob Data Owner"
      principal_id         = data.azurerm_client_config.current.object_id
    }
  }
}

output "storage_account_name" {
  value = module.storage_account.name
}

