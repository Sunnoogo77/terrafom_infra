output "impulse_sql_fqdn" {
  value = module.database.sql_server_fqdn
}

output "impulse_sql_db_name" {
  value = module.database.sql_database_name
}

output "impulse_storage_account_name" {
  value = module.storage.storage_account_name
}

output "impulse_storage_blob_endpoint" {
  value = module.storage.blob_endpoint
}

output "impulse_key_vault_name" {
  value = module.keyvault.key_vault_name
}

output "impulse_key_vault_uri" {
  value = module.keyvault.key_vault_uri
}

output "impulse_acr_name" {
  value = module.acr.name
}

output "impulse_acr_login_server" {
  value = module.acr.login_server
}

# ─────────────────────────────────────────────────────────────────────────────
# Container Apps outputs (conditional - null if not deployed)
# ─────────────────────────────────────────────────────────────────────────────

output "impulse_backend_app_url" {
  description = "Backend Container App URL (null if not deployed)"
  value       = try(module.backend_app[0].backend_app_url, null)
}

output "impulse_backend_app_fqdn" {
  description = "Backend Container App FQDN (null if not deployed)"
  value       = try(module.backend_app[0].backend_app_fqdn, null)
}

output "impulse_backend_identity_principal_id" {
  description = "Backend managed identity principal ID (null if not deployed)"
  value       = try(module.backend_app[0].backend_identity_principal_id, null)
}

output "impulse_aca_env_id" {
  description = "ACA Environment ID (null if backend not deployed)"
  value       = try(module.backend_app[0].aca_env_id, null)
}

# ─────────────────────────────────────────────────────────────────────────────
# AI App outputs - DEPRECATED (AI merged into backend)
# Kept for backwards compatibility, always return null
# ─────────────────────────────────────────────────────────────────────────────

output "impulse_ai_app_url" {
  description = "DEPRECATED: AI service merged into backend. Always null."
  value       = null
}

output "impulse_ai_app_fqdn" {
  description = "DEPRECATED: AI service merged into backend. Always null."
  value       = null
}

output "impulse_ai_identity_principal_id" {
  description = "DEPRECATED: AI service merged into backend. Always null."
  value       = null
}

# ─────────────────────────────────────────────────────────────────────────────
# Frontend output (conditional)
# ─────────────────────────────────────────────────────────────────────────────

output "impulse_frontend_hostname" {
  description = "Frontend Static Web App hostname (null if not deployed)"
  value       = try(module.frontend[0].frontend_default_hostname, null)
}

output "impulse_log_analytics_workspace_name" {
  value = module.monitoring.log_analytics_workspace_name
}