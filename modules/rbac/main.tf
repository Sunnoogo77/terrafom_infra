
terraform {
  required_version = ">= 1.8.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}


data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_role_assignment" "rg_infra_owner" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Owner"
  principal_id         = var.groups.infra
}

resource "azurerm_role_assignment" "rg_devsecops_contrib" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = var.groups.devsecops
}

resource "azurerm_role_assignment" "rg_dev_reader" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = var.groups.dev
}

resource "azurerm_role_assignment" "rg_ia_reader" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = var.groups.ia
}

resource "azurerm_role_assignment" "rg_data_reader" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = var.groups.data
}

resource "azurerm_role_assignment" "rg_security_reader" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Security Reader"
  principal_id         = var.groups.security
}

resource "azurerm_role_assignment" "rg_soc_security_reader" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Security Reader"
  principal_id         = var.groups.soc
}

#Key Vault RBAC
resource "azurerm_role_assignment" "kv_admin" {
  scope                = var.kv_id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.groups.infra
}

resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = var.kv_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.groups.devsecops
}

# Assign Key Vault access to backend and AI managed identities
resource "azurerm_role_assignment" "kv_backend_mi" {
  scope                = var.kv_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.backend_mi_id
}

resource "azurerm_role_assignment" "kv_ai_mi" {
  scope                = var.kv_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.ai_mi_id
}

resource "azurerm_role_assignment" "kv_security_reader" {
  scope                = var.kv_id
  role_definition_name = "Key Vault Reader"
  principal_id         = var.groups.security
}

resource "azurerm_role_assignment" "kv_soc_reader" {
  scope                = var.kv_id
  role_definition_name = "Key Vault Reader"
  principal_id         = var.groups.soc
}

# Allow Storage Account to use Key Vault key for CMK encryption
resource "azurerm_role_assignment" "kv_storage_cmk_user" {
  count                = var.storage_cmk_principal_id == "" ? 0 : 1
  scope                = var.kv_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = var.storage_cmk_principal_id
}

#Storage RBAC
resource "azurerm_role_assignment" "storage_backend_rw" {
  scope                = var.storage_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.backend_mi_id
}

resource "azurerm_role_assignment" "storage_ai_r" {
  scope                = var.storage_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.ai_mi_id
}

resource "azurerm_role_assignment" "storage_dev_r" {
  scope                = var.storage_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.groups.dev
}

#SQL RBAC
resource "azurerm_role_assignment" "sql_data_contrib" {
  scope                = var.sql_id
  role_definition_name = "Contributor"
  principal_id         = var.groups.data
}

#ACR RBAC
resource "azurerm_role_assignment" "acr_backend_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.backend_mi_id
}

resource "azurerm_role_assignment" "acr_ai_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.ai_mi_id
}

resource "azurerm_role_assignment" "acr_devsecops_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = var.groups.devsecops
}

# Log Analytics RBAC (SOC / Security)
resource "azurerm_role_assignment" "law_security_reader" {
  count                = var.law_id == "" ? 0 : 1
  scope                = var.law_id
  role_definition_name = "Log Analytics Reader"
  principal_id         = var.groups.security
}

resource "azurerm_role_assignment" "law_soc_reader" {
  count                = var.law_id == "" ? 0 : 1
  scope                = var.law_id
  role_definition_name = "Log Analytics Reader"
  principal_id         = var.groups.soc
}
