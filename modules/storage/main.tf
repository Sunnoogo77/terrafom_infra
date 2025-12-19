terraform {
  required_version = ">= 1.8.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

variable "env" {
  type = string
}

variable "location" {
  type = string
}

variable "project_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_endpoints_id" {
  type        = string
  description = "Subnet ID where Private Endpoints are created"
}

variable "storage_sku_name" {
  type    = string
  default = "Standard_LRS"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID"
}

variable "cmk_key_id" {
  type        = string
  default     = ""
  description = "Key Vault Key ID for Customer-Managed Key (CMK) encryption"
}

locals {
  storage_account_name             = lower(replace("${var.project_name}stor${var.env}", "/[^a-z0-9]/", ""))
  storage_sku_parts                = split("_", var.storage_sku_name)
  storage_account_tier             = try(local.storage_sku_parts[0], "Standard")
  storage_account_replication_type = try(local.storage_sku_parts[1], "LRS")
}

resource "azurerm_user_assigned_identity" "storage" {
  name                = "${var.project_name}-stor-mi-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "data"
  }
}

# ------------------------------
# Storage Account
# ------------------------------
resource "azurerm_storage_account" "sa" {
  name                     = local.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = local.storage_account_tier
  account_replication_type = local.storage_account_replication_type

  account_kind = "StorageV2"

  public_network_access_enabled = false

  allow_nested_items_to_be_public = false

  shared_access_key_enabled = false

  https_traffic_only_enabled = true

  min_tls_version = "TLS1_2"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage.id]
  }

  sas_policy {
    expiration_period = "01.00:00:00"
    expiration_action = "Log"
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 7
    }
  }

  customer_managed_key {
    key_vault_key_id          = var.cmk_key_id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "data"
  }
}

# ------------------------------
# Blob containers
# ------------------------------
resource "azurerm_storage_container" "cv" {
  name                  = "cv-input"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "lm" {
  name                  = "lm-generated"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "avatars" {
  name                  = "avatars"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "exports" {
  name                  = "exports"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

# ------------------------------
# Private Endpoint for Blob
# ------------------------------
resource "azurerm_private_endpoint" "storage_blob_pe" {
  name                = "${local.storage_account_name}-blob-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_endpoints_id

  private_service_connection {
    name                           = "${local.storage_account_name}-blob-pe-conn"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.sa.id
    subresource_names              = ["blob"]
  }

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "data"
  }
}

# ------------------------------
# (Optionnel) Diagnostics vers Log Analytics
# ------------------------------
resource "azurerm_monitor_diagnostic_setting" "storage_diagnostics" {
  name                       = "${local.storage_account_name}-diag"
  target_resource_id         = azurerm_storage_account.sa.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}

# Blob service diagnostics (some policies expect diagnostics on blobServices/default)
resource "azurerm_monitor_diagnostic_setting" "storage_blob_service_diagnostics" {
  name                       = "${local.storage_account_name}-blob-diag"
  target_resource_id         = "${azurerm_storage_account.sa.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

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

# ------------------------------
# Outputs
# ------------------------------
output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "storage_account_id" {
  value = azurerm_storage_account.sa.id
}

output "storage_identity_principal_id" {
  description = "Principal ID of the user-assigned identity used for Storage CMK"
  value       = azurerm_user_assigned_identity.storage.principal_id
}

output "blob_endpoint" {
  value = azurerm_storage_account.sa.primary_blob_endpoint
}