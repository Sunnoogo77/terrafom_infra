############################################
# Module acr
# Rôle : Azure Container Registry sécurisé
############################################

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
  type        = string
  description = "Environment name (dev, preprod, prod)"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "project_name" {
  type        = string
  description = "Project name (impulse)"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for ACR"
}

variable "subnet_endpoints_id" {
  type        = string
  description = "Subnet ID for Private Endpoints (if enabled)"
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Whether to create a Private Endpoint for ACR"
  default     = false
}

variable "sku" {
  type        = string
  description = "ACR SKU (Basic, Standard, Premium)"
  default     = "Basic"
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = ""
  description = "Log Analytics workspace ID (optional for diagnostics)"
}

locals {
  # ACR name : 5-50 chars, lowercase alphanum only
  raw_name = "${var.project_name}acr${var.env}"
  acr_name = substr(lower(replace(local.raw_name, "/[^a-z0-9]/", "")), 0, 50)
}

# ------------------------------
# Azure Container Registry
# ------------------------------
resource "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  admin_enabled = false

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "registry"
  }
}

# ------------------------------
# Private Endpoint pour ACR (optionnel)
# (souvent créé plus tard car ACR est géré
#  via réseau Microsoft, mais on prépare le terrain)
# ------------------------------
resource "azurerm_private_endpoint" "acr_pe" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${local.acr_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_endpoints_id

  private_service_connection {
    name                           = "${local.acr_name}-pe-conn"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
  }

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "registry"
  }
}

# ------------------------------
# Diagnostics vers Log Analytics (optionnel)
# ------------------------------
resource "azurerm_monitor_diagnostic_setting" "acr_diagnostics" {
  count                      = var.log_analytics_workspace_id == "" ? 0 : 1
  name                       = "${local.acr_name}-diag"
  target_resource_id         = azurerm_container_registry.acr.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}

# ------------------------------
# Outputs
# ------------------------------
output "id" {
  description = "ACR resource ID (for RBAC / AcrPull)"
  value       = azurerm_container_registry.acr.id
}

output "acr_id" {
  description = "ACR resource ID (for RBAC / AcrPull)"
  value       = azurerm_container_registry.acr.id
}

output "login_server" {
  description = "ACR login server (ex: impulseacrdev.azurecr.io)"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_login_server" {
  description = "ACR login server (ex: impulseacrdev.azurecr.io)"
  value       = azurerm_container_registry.acr.login_server
}

output "name" {
  description = "ACR name"
  value       = azurerm_container_registry.acr.name
}

output "acr_name" {
  description = "ACR name"
  value       = azurerm_container_registry.acr.name
}