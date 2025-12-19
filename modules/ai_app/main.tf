############################################
# Module ai_app
# Rôle : App Impulse (AI) dans ACA env existant
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
  description = "Resource group where app is created"
}

variable "aca_env_id" {
  type        = string
  description = "Existing ACA environment ID (from backend_app module)"
}

variable "acr_login_server" {
  type        = string
  description = "ACR login server"
}

variable "ai_image" {
  type        = string
  description = "Full image name without tag (ex: impulse/ai-service)"
}

variable "ai_image_tag" {
  type        = string
  description = "Image tag (ex: latest, dev-123)"
  default     = "latest"
}

variable "container_port" {
  type        = number
  description = "Port exposed by the AI container"
  default     = 8001
}

# Optionnel : URL interne du backend (pour faire des callbacks si besoin)
variable "backend_url" {
  type        = string
  description = "Backend base URL (https://backend...) if needed by AI"
  default     = ""
}

# -----------------------------------------
# Managed Identity pour l'app IA
# -----------------------------------------

resource "azurerm_user_assigned_identity" "ai_app" {
  name                = "${var.project_name}-ai-mi-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# -----------------------------------------
# Container App : impulse-ai
# (pas d’ingress public)
# -----------------------------------------

resource "azurerm_container_app" "ai" {
  name                         = "${var.project_name}-ai-${var.env}"
  container_app_environment_id = var.aca_env_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.ai_app.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.ai_app.id
  }

  # IA = service interne, pas d’endpoint public
  ingress {
    external_enabled = false
    target_port      = var.container_port

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    container {
      name   = "impulse-ai"
      image  = "${var.acr_login_server}/${var.ai_image}:${var.ai_image_tag}"
      cpu    = 1
      memory = "2Gi"

      env {
        name  = "IMPULSE_ENV"
        value = var.env
      }

      # Si tu veux que l'IA appelle le backend :
      env {
        name  = "BACKEND_URL"
        value = var.backend_url
      }

      env {
        name  = "KEYVAULT_URI"
        value = "" # à remplir plus tard
      }
    }

    min_replicas = 0
    max_replicas = 3
  }

  tags = {
    Project = var.project_name
    Env     = var.env
    App     = "ai"
  }
}
