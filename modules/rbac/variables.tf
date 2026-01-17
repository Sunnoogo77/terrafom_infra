variable "resource_group_id" { type = string }

variable "backend_mi_id" {
  type        = string
  description = "Principal ID of the backend managed identity. Empty string to skip backend MI role assignments."
  default     = ""
}

variable "ai_mi_id" {
  type        = string
  description = "Principal ID of the AI managed identity. Empty string to skip AI MI role assignments."
  default     = ""
}

variable "kv_id" { type = string }
variable "storage_id" { type = string }
variable "sql_id" { type = string }
variable "acr_id" { type = string }
variable "law_id" {
  type        = string
  description = "Log Analytics Workspace ID for SOC reader role"
  default     = ""
}
variable "enable_law_rbac" {
  type        = bool
  description = "Create SOC/Security Reader assignments on LAW"
  default     = false
}

variable "storage_cmk_principal_id" {
  type        = string
  description = "Principal ID of the Storage Account managed identity (for Key Vault CMK access)"
  default     = ""
}
variable "enable_storage_cmk_role" {
  type        = bool
  description = "Create role assignment for Storage CMK identity on Key Vault"
  default     = false
}

variable "groups" {
  type = object({
    infra     = string
    dev       = string
    devsecops = string
    ia        = string
    data      = string
    security  = string
    soc       = string
  })
}
