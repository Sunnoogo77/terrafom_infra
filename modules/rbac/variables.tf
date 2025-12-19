variable "resource_group_name" { type = string }
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
