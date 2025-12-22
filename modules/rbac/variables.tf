variable "resource_group_id" { type = string }
variable "resource_group_name" {
  type        = string
  default     = ""
  description = "Optional RG name (kept for compatibility)"
}
variable "backend_mi_id" { type = string }
variable "ai_mi_id" { type = string }

variable "kv_id" { type = string }
variable "storage_id" { type = string }
variable "sql_id" { type = string }
variable "acr_id" { type = string }
variable "law_id" {
  type        = string
  description = "Log Analytics Workspace ID for SOC reader role"
  default     = ""
}

variable "storage_cmk_principal_id" {
  type        = string
  description = "Principal ID of the Storage Account managed identity (for Key Vault CMK access)"
  default     = ""
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
