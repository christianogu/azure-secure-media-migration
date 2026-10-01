terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
        source = "hashicorp/random"
        version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true
}

variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "eastus"
}

# ---------- Resource group ----------
resource "azurerm_resource_group" "main" {
  name     = "rg-hyenlo-tf"
  location = var.location
}

# ---------- Network ----------
resource "azurerm_virtual_network" "main" {
  name                = "vnet-hyenlo"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# ---------- Firewall (NSG) ----------
resource "azurerm_network_security_group" "workload" {
  name                = "nsg-workload"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}
variable "allowed_ip" {
  type        = string
  description = "The only public IP allowed to reach storage (the on-prem source)"
}

# Who is running Terraform (used to grant upload access)
data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

# ---------- Storage ----------
resource "azurerm_storage_account" "main" {
  name                            = "sthyenlotf${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  access_tier                     = "Hot"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Deny"
    ip_rules       = [var.allowed_ip]
  }
}

resource "azurerm_storage_container" "footage" {
  name                  = "footage"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# ---------- Identity: least-privilege upload access ----------
resource "azurerm_role_assignment" "me_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------- Lifecycle: Hot -> Cool -> Archive ----------
resource "azurerm_storage_management_policy" "tiering" {
  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "footage-tiering"
    enabled = true

    filters {
      prefix_match = ["footage/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
      }
      version {
        delete_after_days_since_creation = 30
      }
    }
  }
}

# ---------- Monitoring ----------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-hyenlo"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "blob" {
  name                       = "diag-blob"
  target_resource_id         = "${azurerm_storage_account.main.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}