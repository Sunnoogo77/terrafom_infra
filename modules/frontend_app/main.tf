############################################
# Module frontend
# Rôle : Azure Static Web App (React/Vue)
############################################

variable "env" {
  type        = string
  description = "Environment name (dev, preprod, prod)"
}

variable "location" {
  type        = string
  description = "Azure region (Static Web Apps support quelques régions)"
}

variable "project_name" {
  type        = string
  description = "Project name (impulse)"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where the Static Web App is created"
}

variable "repository_url" {
  type        = string
  description = "Git repository URL (GitHub) for the frontend source"
}

variable "custom_domain_name" {
  type        = string
  description = "Custom domain name for the Static Web App (optional, e.g. app.example.com)"
  default     = ""
}

variable "branch" {
  type        = string
  description = "Git branch to build/deploy"
}

variable "sku_tier" {
  type        = string
  description = "SKU tier (Free, Standard, etc.)"
  default     = "Free"
}

variable "sku_size" {
  type        = string
  description = "SKU size"
  default     = "Free"
}

variable "backend_url" {
  type        = string
  description = "Backend base URL (https://...) used by the frontend"
}

# Optionnel : si tu veux envoyer l'env au front
variable "app_env" {
  type        = string
  description = "Environment name exposed to frontend"
  default     = ""
}

locals {
  static_web_app_name = "${var.project_name}-frontend-${var.env}"
}

resource "azurerm_static_web_app" "frontend" {
  name                = local.static_web_app_name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku_tier = var.sku_tier
  sku_size = var.sku_size

  # Tu peux adapter ces settings selon ta structure (React/Vite, etc.)
  # Ici on part sur un front type Vite/React servi en build.
  app_settings = {
    # URL de l'API backend utilisée par le frontend
    "VITE_BACKEND_URL" = var.backend_url

    # Optionnel : env pour afficher "dev", "prod", etc.
    "VITE_IMPULSE_ENV" = var.app_env != "" ? var.app_env : var.env
  }

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "frontend"
  }
}

resource "azurerm_static_web_app_custom_domain" "frontend_domain" {
  count             = var.custom_domain_name == "" ? 0 : 1
  static_web_app_id = azurerm_static_web_app.frontend.id
  domain_name       = var.custom_domain_name
  validation_type   = "cname-delegation"
}

output "frontend_default_hostname" {
  description = "Default hostname of the Static Web App"
  value       = azurerm_static_web_app.frontend.default_host_name
}

output "frontend_name" {
  value = azurerm_static_web_app.frontend.name
}