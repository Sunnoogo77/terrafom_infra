variable "env" {
  type        = string
  description = "Environment name (dev, preprod, prod)"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "westeurope"
}

variable "project_name" {
  type    = string
  default = "impulse"
}

variable "address_space" {
  type    = string
  default = "10.10.0.0/16"
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

variable "sql_sku_name" {
  type        = string
  description = "SKU for Azure SQL Database"
  default     = "GP_S_Gen5_2" # ou Basic, etc.
}

variable "storage_sku_name" {
  type        = string
  description = "SKU for the storage account"
  default     = "Standard_LRS"
}


variable "frontend_repository_url" {
  type        = string
  description = "Git repository URL for the frontend (Static Web App source)"
}

variable "frontend_branch" {
  type        = string
  description = "Branch to build/deploy for the frontend"
  default     = "main"
}

variable "frontend_sku_tier" {
  type        = string
  description = "SKU tier for Static Web App (Free, Standard, etc.)"
  default     = "Free"
}

variable "frontend_sku_size" {
  type        = string
  description = "SKU size for Static Web App"
  default     = "Free"
}
