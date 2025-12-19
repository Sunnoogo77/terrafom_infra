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
  default     = ""
  description = "Log Analytics workspace ID (optional for diagnostics)"
}

locals {
  storage_account_name = lower(replace("${var.project_name}stor${var.env}", "/[^a-z0-9]/", ""))
}

# ------------------------------
# Storage Account
# ------------------------------
resource "azurerm_storage_account" "sa" {
  name                     = local.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  account_kind = "StorageV2"

  public_network_access_enabled = false

  https_traffic_only_enabled = true

  min_tls_version = "TLS1_2"

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
  count                      = var.log_analytics_workspace_id == "" ? 0 : 1
  name                       = "${local.storage_account_name}-diag"
  target_resource_id         = azurerm_storage_account.sa.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "StorageWrite"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "StorageDelete"

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "Transaction"
    enabled  = true

    retention_policy {
      enabled = false
    }
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

output "blob_endpoint" {
  value = azurerm_storage_account.sa.primary_blob_endpoint
}