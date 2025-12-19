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

variable "sql_admin_login" {
  type        = string
  description = "Admin login for Azure SQL Server"
}

variable "sql_admin_password" {
  type        = string
  description = "Admin password for Azure SQL Server"
  sensitive   = true
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID (for Azure AD admin configuration)"
}

variable "azuread_admin_login_username" {
  type        = string
  description = "Azure AD admin login username (group display name or UPN)"
}

variable "azuread_admin_object_id" {
  type        = string
  description = "Azure AD object id for the SQL Azure AD admin (group or user)"
}


variable "sql_sku_name" {
  type = string
}

# Optionnel pour brancher plus tard les logs vers Log Analytics
variable "log_analytics_workspace_id" {
  type        = string
  default     = ""
  description = "Log Analytics workspace ID (optional for diagnostics)"
}

locals {
  sql_server_name = "${var.project_name}-sql-${var.env}"
  sql_db_name     = "${var.project_name}-db-${var.env}"
}

# ------------------------------
# Azure SQL Server (PaaS)
# ------------------------------
resource "azurerm_mssql_server" "sql_server" {
  name                = local.sql_server_name
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "12.0"

  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password


  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  azuread_administrator {
    login_username = var.azuread_admin_login_username
    object_id      = var.azuread_admin_object_id
    tenant_id      = var.tenant_id

    azuread_authentication_only = false
  }

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "data"
  }
}

# Audit étendu (recommandé). Si un Log Analytics Workspace est configuré via
# les diagnostic settings ci-dessous, les events d'audit y seront envoyés.
resource "azurerm_mssql_server_extended_auditing_policy" "sql_audit" {
  server_id              = azurerm_mssql_server.sql_server.id
  log_monitoring_enabled = true
  retention_in_days      = 90
}

# ------------------------------
# Azure SQL Database
# ------------------------------
resource "azurerm_mssql_database" "sql_db" {
  name        = local.sql_db_name
  server_id   = azurerm_mssql_server.sql_server.id
  sku_name    = var.sql_sku_name
  max_size_gb = 10

  # On peut activer ça plus tard si besoin
  auto_pause_delay_in_minutes = -1

  zone_redundant = true
  ledger_enabled = true

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "data"
  }
}

# ------------------------------
# Private Endpoint for SQL
# ------------------------------
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "${local.sql_server_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_endpoints_id

  private_service_connection {
    name                           = "${local.sql_server_name}-pe-conn"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
  }

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "data"
  }
}

# ------------------------------
# (Optionnel) Diagnostic Settings vers Log Analytics
# ------------------------------
resource "azurerm_monitor_diagnostic_setting" "sql_diagnostics" {
  count                      = var.log_analytics_workspace_id == "" ? 0 : 1
  name                       = "${local.sql_server_name}-diag"
  target_resource_id         = azurerm_mssql_server.sql_server.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "SQLSecurityAuditEvents"

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
output "sql_server_id" {
  value = azurerm_mssql_server.sql_server.id
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "sql_database_name" {
  value = azurerm_mssql_database.sql_db.name
}
