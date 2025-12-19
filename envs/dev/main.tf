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

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}


module "storage" {
  source              = "../../modules/storage"
  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name
  subnet_endpoints_id = module.network.subnet_endpoints_id

  storage_sku_name = var.storage_sku_name

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
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
}

module "acr" {
  source = "../../modules/acr"

  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name

  subnet_endpoints_id     = module.network.subnet_endpoints_id
  enable_private_endpoint = false

  sku = "Basic"

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}


module "backend_app" {
  source = "../../modules/backend_app"

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


module "ai_app" {
  source = "../../modules/ai_app"

  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name

  aca_env_id       = module.backend_app.aca_env_id
  acr_login_server = module.acr.login_server

  ai_image       = "impulse/ai-service"
  ai_image_tag   = "dev"
  container_port = 8001

  backend_url = "https://${module.backend_app.backend_fqdn}"
}



module "frontend" {
  source = "../../modules/frontend_app"


  env                 = var.env
  location            = var.location
  project_name        = var.project_name
  resource_group_name = module.network.resource_group_name

  repository_url = var.frontend_repository_url
  branch         = var.frontend_branch

  sku_tier = var.frontend_sku_tier
  sku_size = var.frontend_sku_size

  backend_url = "https://${module.backend_app.backend_fqdn}"
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

  resource_group_name = module.network.resource_group_name

  backend_mi_id = module.backend_app.backend_identity_principal_id
  ai_mi_id      = module.ai_app.ai_identity_principal_id

  kv_id      = module.keyvault.key_vault_id
  storage_id = module.storage.storage_account_id
  sql_id     = module.database.sql_server_id
  acr_id     = module.acr.acr_id
  law_id     = module.monitoring.log_analytics_workspace_id

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

