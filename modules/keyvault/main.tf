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

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

variable "subnet_endpoints_id" {
  type        = string
  description = "Subnet ID where Private Endpoints are created"
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = ""
  description = "Log Analytics workspace ID (optional for diagnostics)"
}

locals {
  key_vault_name = lower(replace("${var.project_name}-kv-${var.env}", "/[^a-z0-9-]/", ""))
}

# ------------------------------
# Azure Key Vault
# ------------------------------
resource "azurerm_key_vault" "kv" {
  name                = local.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "premium"

  # Sécurité forte
  soft_delete_retention_days  = 30
  purge_protection_enabled    = true
  enabled_for_disk_encryption = false

  # On active RBAC, pas de access_policies dans le code
  enable_rbac_authorization = true

  # On restreint le réseau
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"

    # Le trafic autorisé passera en réalité par le Private Endpoint.
    virtual_network_subnet_ids = [var.subnet_endpoints_id]
    ip_rules                   = []
  }

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "security"
  }
}

# ------------------------------
# Private Endpoint pour Key Vault
# ------------------------------
resource "azurerm_private_endpoint" "kv_pe" {
  name                = "${local.key_vault_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_endpoints_id

  private_service_connection {
    name                           = "${local.key_vault_name}-pe-conn"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
  }

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "security"
  }
}

# ------------------------------
# (Optionnel) Diagnostics vers Log Analytics
# ------------------------------
resource "azurerm_monitor_diagnostic_setting" "kv_diagnostics" {
  count                      = var.log_analytics_workspace_id == "" ? 0 : 1
  name                       = "${local.key_vault_name}-diag"
  target_resource_id         = azurerm_key_vault.kv.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# CMK used for encryption at rest (e.g., Storage Account)
resource "azurerm_key_vault_key" "storage_cmk" {
  name         = "${var.project_name}-storage-cmk-${var.env}"
  key_vault_id = azurerm_key_vault.kv.id

  key_type = "RSA-HSM"
  key_size = 2048

  expiration_date = "2030-01-01T00:00:00Z"

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}

# ------------------------------
# Outputs
# ------------------------------
output "key_vault_id" {
  value = azurerm_key_vault.kv.id
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "storage_cmk_key_id" {
  description = "Key Vault key id to use as CMK for Storage encryption"
  value       = azurerm_key_vault_key.storage_cmk.id
}