############################################
# Module monitoring
# Rôle : Log Analytics Workspace central
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
  description = "Resource group where the workspace is created"
}

variable "retention_in_days" {
  type        = number
  description = "Log retention in days"
  default     = 30
}

locals {
  log_analytics_name = "${var.project_name}-law-${var.env}"
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = local.log_analytics_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku               = "PerGB2018"
  retention_in_days = var.retention_in_days

  tags = {
    Project = var.project_name
    Env     = var.env
    Layer   = "monitoring"
  }
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law.name
}