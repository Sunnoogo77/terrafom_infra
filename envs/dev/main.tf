module "network" {
  source        = "../../modules/network"
  env           = var.env
  location      = var.location
  project_name  = var.project_name
  address_space = var.address_space
}

module "groups" {
  source       = "../../modules/groups"
  project_name = var.project_name
}

module "database" {
  source              = "../../modules/database"
  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name
  subnet_endpoints_id = module.network.subnet_endpoints_id

  sql_admin_login    = var.sql_admin_login
  sql_admin_password = var.sql_admin_password
  sql_sku_name       = var.sql_sku_name

  tenant_id                    = data.azurerm_client_config.current.tenant_id
  azuread_admin_login_username = module.groups.display_names.devsecops
  azuread_admin_object_id      = module.groups.object_ids.devsecops

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  enable_diagnostics         = true
}


module "storage" {
  source              = "../../modules/storage"
  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name
  subnet_endpoints_id = module.network.subnet_endpoints_id

  storage_sku_name = var.storage_sku_name

  cmk_key_id = module.keyvault.storage_cmk_key_id

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  enable_diagnostics         = true
}


module "keyvault" {
  source              = "../../modules/keyvault"
  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name

  tenant_id           = data.azurerm_client_config.current.tenant_id
  subnet_endpoints_id = module.network.subnet_endpoints_id

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  enable_diagnostics         = true
}

module "acr" {
  source = "../../modules/acr"

  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name

  subnet_endpoints_id     = module.network.subnet_endpoints_id
  enable_private_endpoint = true

  sku                      = "Premium"
  georeplication_locations = ["northeurope"]

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  enable_diagnostics         = true
}


# ─────────────────────────────────────────────────────────────────────────────
# Container Apps (conditional - requires images in ACR)
# Set deploy_apps = true when images are available
# ─────────────────────────────────────────────────────────────────────────────

module "backend_app" {
  source = "../../modules/backend_app"
  count  = var.deploy_apps ? 1 : 0

  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name
  subnet_backend_id   = module.network.subnet_backend_id

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  acr_login_server = module.acr.login_server

  backend_image     = "impulse/backend-core"
  backend_image_tag = "dev"
  container_port    = 8000

  ingress_external_enabled = true
}

# NOTE: AI service has been merged into backend.
# The ai_app module is no longer deployed.
# To re-enable AI as a separate service in the future, uncomment and adapt:
#
# module "ai_app" {
#   source = "../../modules/ai_app"
#   count  = var.deploy_apps ? 1 : 0
#
#   env                 = var.env
#   location            = var.location
#   project_name        = var.project_name
#   resource_group_name = module.network.resource_group_name
#
#   aca_env_id       = module.backend_app[0].aca_env_id
#   acr_login_server = module.acr.login_server
#
#   ai_image       = "impulse/ai-service"
#   ai_image_tag   = "dev"
#   container_port = 8001
#
#   backend_url = "https://${module.backend_app[0].backend_fqdn}"
# }



# ─────────────────────────────────────────────────────────────────────────────
# Frontend (Static Web App) - conditional deployment
# ─────────────────────────────────────────────────────────────────────────────

module "frontend" {
  source = "../../modules/frontend_app"
  count  = var.deploy_frontend ? 1 : 0

  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name

  repository_url = var.frontend_repository_url
  branch         = var.frontend_branch

  sku_tier = var.frontend_sku_tier
  sku_size = var.frontend_sku_size

  # Safe reference: use backend FQDN if deployed, otherwise empty string
  backend_url = var.deploy_apps ? "https://${module.backend_app[0].backend_fqdn}" : ""
  app_env     = var.env
}

module "monitoring" {
  source = "../../modules/monitoring"

  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name

  retention_in_days = 30
}

module "rbac" {
  source = "../../modules/rbac"

  resource_group_id = module.network.resource_group_id

  # Safe references: pass empty string if apps not deployed
  # RBAC module will skip role assignments for empty principal IDs
  backend_mi_id = var.deploy_apps ? module.backend_app[0].backend_identity_principal_id : ""
  ai_mi_id      = "" # AI service merged into backend - no separate identity

  kv_id      = module.keyvault.key_vault_id
  storage_id = module.storage.storage_account_id
  sql_id     = module.database.sql_server_id
  acr_id     = module.acr.acr_id
  law_id     = module.monitoring.log_analytics_workspace_id

  storage_cmk_principal_id = module.storage.storage_identity_principal_id
  enable_storage_cmk_role  = true
  enable_law_rbac          = true

  groups = {
    infra     = module.groups.object_ids.infra
    dev       = module.groups.object_ids.dev
    devsecops = module.groups.object_ids.devsecops
    ia        = module.groups.object_ids.ia
    data      = module.groups.object_ids.data
    security  = module.groups.object_ids.security
    soc       = module.groups.object_ids.soc
  }
}

# 
