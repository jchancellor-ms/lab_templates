//cerate naming and resource group resources
resource "random_string" "name_suffix" {  
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  location = var.sddc.location
  name     = "${var.sddc.name_prefix}-rg-dc-${random_string.name_suffix.result}"

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_public_ip" "bastion_pip" {

  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = "${var.sddc.name_prefix}-bastion-pip-${random_string.name_suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags                = local.tags
  zones               = null
}

resource "azurerm_bastion_host" "bastion" {


  location            = azurerm_resource_group.this.location
  name                = "${var.sddc.name_prefix}-bastion-${random_string.name_suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                 = "${var.sddc.name_prefix}-bastion-${random_string.name_suffix.result}-ipconf"
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
    subnet_id            = var.bastion_subnet_resource_id
  }
}

#Create a self-signed certificate for DSC to use for encrypted deployment
resource "azurerm_key_vault_certificate" "this" {
  key_vault_id = var.key_vault_resource_id
  name         = "dc01${var.sddc.name_prefix}-dsc-cert"
  tags         = local.tags

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    key_properties {
      exportable = true
      key_type   = "RSA"
      reuse_key  = true
      key_size   = 2048
    }
    secret_properties {
      content_type = "application/x-pkcs12"
    }
    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }
    x509_certificate_properties {
      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]
      subject            = "CN=dc01${var.sddc.name_prefix}"
      validity_in_months = 12
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1", "1.3.6.1.5.5.7.3.2", "2.5.29.37", "1.3.6.1.4.1.311.80.1"]

      subject_alternative_names {
        dns_names = ["dc01${var.sddc.name_prefix}.${local.domain_fqdn}"]
      }
    }
  }
}

#Create the template script file
data "template_file" "run_script" {
  template = file("${path.module}/templates/dc_configure_script.ps1")
  vars = {
    thumbprint                   = azurerm_key_vault_certificate.this.thumbprint
    admin_username               = module.testvm.virtual_machine.admin_username
    admin_password               = module.testvm.admin_password
    active_directory_fqdn        = local.domain_fqdn
    active_directory_netbios     = local.domain_netbios_name
    ca_common_name               = "${local.domain_netbios_name} Root CA"
    ca_distinguished_name_suffix = local.domain_distinguished_name
    script_url                   = var.dc_dsc_script_url
    ldap_user                    = local.ldap_user_name
    ldap_user_password           = random_password.ldap_password.result
    test_admin                   = local.test_admin_user_name
    test_admin_password          = random_password.test_admin_password.result
    admin_group_name             = local.test_admin_group_name
    primary_admin_password       = module.testvm.admin_password
  }
}


#build the DC VM
locals {
  protected_settings_script_primary = jsonencode({
    commandToExecute = "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.run_script.rendered)}')) | Out-File -filepath run_script.ps1\" && powershell -ExecutionPolicy Unrestricted -File run_script.ps1"
  })
}
#create the virtual machine
module "testvm" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "=0.18.0"

  resource_group_name                    = azurerm_resource_group.this.name
  location                               = azurerm_resource_group.this.location
  os_type                                = "Windows"
  name                                   = "dc01${var.sddc.name_prefix}"
  #admin_credential_key_vault_resource_id = var.key_vault_resource_id
  sku_size                               = var.dc_vm_sku
  zone                                   = null
  generate_admin_password_or_ssh_key = false
  admin_password = random_password.dc1_password.result

  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  managed_identities = {
    system_assigned = true
  }

  network_interfaces = {
    network_interface_1 = {
      name = "dc01${var.sddc.name_prefix}-nic1"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "dc01${var.sddc.name_prefix}-nic1-ipconfig1"
          private_ip_subnet_resource_id = var.dc_subnet_resource_id
          private_ip_address            = cidrhost(var.dc_subnet_cidr, 4)
        }
      }
    }
  }

  secrets = [
    {
      key_vault_id = var.key_vault_resource_id
      certificate = [
        {
          url   = azurerm_key_vault_certificate.this.secret_id
          store = "My"
        },
        {
          store = "Root"
          url   = azurerm_key_vault_certificate.this.secret_id
        }
      ]
    }
  ]

  extensions = {
    configure_domain_controller = {
      name                       = "${module.testvm.virtual_machine.name}-configure-domain-controller"
      publisher                  = "Microsoft.Compute"
      type                       = "CustomScriptExtension"
      type_handler_version       = "1.9"
      auto_upgrade_minor_version = true
      protected_settings         = local.protected_settings_script_primary
    }
  }

  role_assignments_system_managed_identity = var.is_skillable ? {} :{
    role_assignment_1 = {
      scope_resource_id          = var.key_vault_resource_id
      role_definition_id_or_name = "Key Vault Secrets Officer"
      description                = "Assign the Key Vault Secrets Officer role to the virtual machine's system managed identity"
      principal_type             = "ServicePrincipal"
    }
  }
  
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_access_policy" "dc1_smi" {
  count = var.is_skillable ? 1 : 0

  key_vault_id = var.key_vault_resource_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.testvm.system_assigned_mi_principal_id

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

#adding sleep wait to give the DC time to install the features and configure itself
resource "time_sleep" "wait_600_seconds" {
  create_duration = "600s"
  triggers = {
    dc_01 = module.testvm.resource_id
  }

  depends_on = [module.testvm]
}

data "azurerm_virtual_machine" "this_vm" {
  name                = module.testvm.virtual_machine.name
  resource_group_name = azurerm_resource_group.this.name

  depends_on = [time_sleep.wait_600_seconds, module.testvm]
}

#generate a password for use by the ldap user account
resource "random_password" "ldap_password" {
  length           = 22
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  override_special = "!#"
  special          = true
}

resource "random_password" "test_admin_password" {
  length           = 22
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  override_special = "!#"
  special          = true
}

#generate a password for use by the ldap user account
resource "random_password" "dc1_password" {
  length           = 22
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  override_special = "!#"
  special          = true
}

resource "random_password" "dc2_password" {
  length           = 22
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  override_special = "!#"
  special          = true
}

#store the ldap user account in the key vault as a secret
resource "azurerm_key_vault_secret" "ldap_password" {
  key_vault_id = var.key_vault_resource_id
  name         = "${local.ldap_user_name}-password"
  value        = random_password.ldap_password.result
  tags         = local.tags
}

#store the testadmin user account in the key vault as a secret
resource "azurerm_key_vault_secret" "test_admin_password" {
  key_vault_id = var.key_vault_resource_id
  name         = "${local.test_admin_user_name}-password"
  value        = random_password.test_admin_password.result
  tags         = local.tags
}

resource "azurerm_key_vault_secret" "dc01_password" {
  key_vault_id = var.key_vault_resource_id
  name         = "dc01-password"
  value        = random_password.dc1_password.result
  tags         = local.tags
}

resource "azurerm_key_vault_secret" "dc02_password" {
  key_vault_id = var.key_vault_resource_id
  name         = "dc02-password"
  value        = random_password.dc2_password.result
  tags         = local.tags
}

resource "azurerm_virtual_network_dns_servers" "dc_dns" {
  virtual_network_id = var.virtual_network_resource_id
  dns_servers        = [module.testvm.virtual_machine.private_ip_address]

  depends_on = [module.testvm]
}


###############################################################
# Create secondary DC
###############################################################

#Create a self-signed certificate for DSC to use for encrypted deployment
resource "azurerm_key_vault_certificate" "this_secondary" {
  key_vault_id = var.key_vault_resource_id
  name         = "dc02${var.sddc.name_prefix}-dsc-cert"
  tags         = local.tags

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    key_properties {
      exportable = true
      key_type   = "RSA"
      reuse_key  = true
      key_size   = 2048
    }
    secret_properties {
      content_type = "application/x-pkcs12"
    }
    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }
    x509_certificate_properties {
      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]
      subject            = "CN=dc02${var.sddc.name_prefix}"
      validity_in_months = 12
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1", "1.3.6.1.5.5.7.3.2", "2.5.29.37", "1.3.6.1.4.1.311.80.1"]

      subject_alternative_names {
        dns_names = ["dc02${var.sddc.name_prefix}.${local.domain_fqdn}"]
      }
    }
  }
}

#Create the template script file
data "template_file" "run_script_secondary" {
  template = file("${path.module}/templates/dc_configure_script.ps1")
  vars = {
    thumbprint                   = azurerm_key_vault_certificate.this_secondary.thumbprint
    admin_username               = module.testvm_secondary.virtual_machine.admin_username
    admin_password               = module.testvm_secondary.admin_password
    active_directory_fqdn        = local.domain_fqdn
    active_directory_netbios     = local.domain_netbios_name
    ca_common_name               = "${local.domain_netbios_name} Root CA"
    ca_distinguished_name_suffix = local.domain_distinguished_name
    script_url                   = var.dc_dsc_script_url_secondary
    ldap_user                    = local.ldap_user_name
    ldap_user_password           = random_password.ldap_password.result
    test_admin                   = local.test_admin_user_name
    test_admin_password          = random_password.test_admin_password.result
    admin_group_name             = local.test_admin_group_name
    primary_admin_password       = module.testvm.admin_password
  }
}


#build the secondary DC VM
locals {
  protected_settings_script_secondary = jsonencode({
    commandToExecute = "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.run_script_secondary.rendered)}')) | Out-File -filepath run_script.ps1\" && powershell -ExecutionPolicy Unrestricted -File run_script.ps1"
  })
}
#create the virtual machine
module "testvm_secondary" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "=0.18.0"

  resource_group_name                    = azurerm_resource_group.this.name
  location                               = azurerm_resource_group.this.location
  os_type                                = "Windows"
  name                                   = "dc02${var.sddc.name_prefix}"
  #admin_credential_key_vault_resource_id = var.key_vault_resource_id
  sku_size                               = var.dc_vm_sku
  zone                                   = null
  admin_password                         = random_password.dc1_password.result
  generate_admin_password_or_ssh_key     = false


  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  managed_identities = {
    system_assigned = true
  }

  network_interfaces = {
    network_interface_1 = {
      name = "dc02${var.sddc.name_prefix}-nic1"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "dc02${var.sddc.name_prefix}-nic1-ipconfig1"
          private_ip_subnet_resource_id = var.dc_subnet_resource_id
          private_ip_address            = cidrhost(var.dc_subnet_cidr, 5)
        }
      }
    }
  }

  secrets = [
    {
      key_vault_id = var.key_vault_resource_id
      certificate = [
        {
          url   = azurerm_key_vault_certificate.this_secondary.secret_id
          store = "My"
        },
        {
          store = "Root"
          url   = azurerm_key_vault_certificate.this_secondary.secret_id
        }
      ]
    }
  ]

  extensions = {
    configure_domain_controller = {
      name                       = "${module.testvm_secondary.virtual_machine.name}-configure-domain-controller"
      publisher                  = "Microsoft.Compute"
      type                       = "CustomScriptExtension"
      type_handler_version       = "1.9"
      auto_upgrade_minor_version = true
      protected_settings         = local.protected_settings_script_secondary
    }
  }

  role_assignments_system_managed_identity = var.is_skillable ? {} : {
    role_assignment_1 = {
      scope_resource_id          = var.key_vault_resource_id
      role_definition_id_or_name = "Key Vault Secrets Officer"
      description                = "Assign the Key Vault Secrets Officer role to the virtual machine's system managed identity"
      principal_type             = "ServicePrincipal"
    }
  }

  depends_on = [module.testvm, azurerm_virtual_network_dns_servers.dc_dns, time_sleep.wait_600_seconds, data.azurerm_virtual_machine.this_vm]
}

resource "azurerm_key_vault_access_policy" "dc2_smi" {
  count = var.is_skillable ? 1 : 0

  key_vault_id = var.key_vault_resource_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.testvm_secondary.system_assigned_mi_principal_id

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

#adding sleep wait to give the DC time to install the features and configure itself
resource "time_sleep" "wait_600_seconds_2" {
  create_duration = "600s"
  triggers = {
    dc_02 = module.testvm_secondary.resource_id
  }

  depends_on = [module.testvm_secondary]
}

data "azurerm_virtual_machine" "this_vm_secondary" {
  name                = module.testvm_secondary.virtual_machine.name
  resource_group_name = azurerm_resource_group.this.name

  depends_on = [time_sleep.wait_600_seconds_2, module.testvm_secondary]
}




