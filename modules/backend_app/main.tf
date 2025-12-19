############################################
# Module backend_app
# Rôle : ACA Environment + App Impulse (backend)
############################################

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
  description = "Resource group where ACA env + apps are created"
}

variable "subnet_backend_id" {
  type        = string
  description = "Subnet ID used for the Container Apps environment (injected VNet)"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics Workspace ID for diagnostics"
}

variable "acr_login_server" {
  type        = string
  description = "ACR login server (ex: impulseacr.azurecr.io)"
}

variable "backend_image" {
  type        = string
  description = "Full image name without tag (ex: impulse/backend-core)"
}

variable "backend_image_tag" {
  type        = string
  description = "Image tag (ex: latest, dev-123)"
  default     = "latest"
}

variable "container_port" {
  type        = number
  description = "Port exposed by the backend container"
  default     = 8000
}

variable "ingress_external_enabled" {
  type        = bool
  description = "Whether the backend is exposed publicly (true for dev, false for prod)"
  default     = true
}

# -----------------------------------------
# Managed Identity pour l'app backend
# -----------------------------------------

resource "azurerm_user_assigned_identity" "backend_app" {
  name                = "${var.project_name}-backend-mi-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# -----------------------------------------
# Environment Azure Container Apps
# (partagé backend + IA)
# -----------------------------------------

resource "azurerm_container_app_environment" "aca_env" {
  name                       = "${var.project_name}-aca-env-${var.env}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Injection réseau : l'environnement entier est dans ce subnet
  infrastructure_subnet_id = var.subnet_backend_id

  zone_redundancy_enabled = false

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "app"
  }
}

# -----------------------------------------
# Container App : impulse-core (backend)
# -----------------------------------------

resource "azurerm_container_app" "backend" {
  name                         = "${var.project_name}-backend-${var.env}"
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.backend_app.id]
  }

  # ACR pour récupérer l'image
  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.backend_app.id
  }

  # Ingress (public pour dev, private pour prod)
  ingress {
    external_enabled = var.ingress_external_enabled
    target_port      = var.container_port

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    container {
      name   = "impulse-backend"
      image  = "${var.acr_login_server}/${var.backend_image}:${var.backend_image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      # Pas de secrets ici: on passe uniquement des infos non sensibles.
      env {
        name  = "IMPULSE_ENV"
        value = var.env
      }

      env {
        name  = "KEYVAULT_URI"
        value = "" # à remplir plus tard via variables/envs/dev
      }

      env {
        name  = "STORAGE_ACCOUNT_NAME"
        value = "" # idem, non sensible
      }
    }

    min_replicas = 1
    max_replicas = 3
  }

  tags = {
    Project = var.project_name
    Env     = var.env
    App     = "backend"
  }
}
