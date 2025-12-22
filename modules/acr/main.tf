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
  default     = "Premium"
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Whether public network access is enabled for ACR"
  default     = false
}

variable "data_endpoint_enabled" {
  type        = bool
  description = "Enable dedicated data endpoints (Premium feature)"
  default     = true
}



variable "quarantine_policy_enabled" {
  type        = bool
  description = "Enable image quarantine policy (Premium feature)"
  default     = true
}

variable "trust_policy_enabled" {
  type        = bool
  description = "Enable content trust policy"
  default     = true
}

variable "retention_policy_days" {
  type        = number
  description = "Retention (days) to cleanup untagged manifests"
  default     = 7
}

variable "georeplication_locations" {
  type        = list(string)
  description = "Additional regions for geo-replication (Premium feature)"
  default     = ["northeurope"]
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = ""
  description = "Log Analytics workspace ID (optional for diagnostics)"
}

variable "enable_diagnostics" {
  type        = bool
  description = "Enable diagnostics to Log Analytics"
  default     = false
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

  public_network_access_enabled = var.public_network_access_enabled

  data_endpoint_enabled     = var.data_endpoint_enabled
  zone_redundancy_enabled   = true
  quarantine_policy_enabled = var.quarantine_policy_enabled

  trust_policy_enabled     = var.trust_policy_enabled
  retention_policy_in_days = var.retention_policy_days

  network_rule_set {
    default_action = "Deny"
  }

  dynamic "georeplications" {
    for_each = toset(var.georeplication_locations)
    content {
      location                = georeplications.value
      zone_redundancy_enabled = true
    }
  }

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
  count                      = var.enable_diagnostics ? 1 : 0
  name                       = "${local.acr_name}-diag"
  target_resource_id         = azurerm_container_registry.acr.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
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
