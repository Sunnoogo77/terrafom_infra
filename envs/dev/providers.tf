terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.50"
    }
  }

  backend "local" {}
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

data "azurerm_client_config" "current" {}

# Defender for Cloud - enable vulnerability scanning for ACR images
resource "azurerm_security_center_subscription_pricing" "container_registry" {
  tier          = "Standard"
  resource_type = "ContainerRegistry"
}
