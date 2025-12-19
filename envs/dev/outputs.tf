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

output "impulse_backend_app_url" {
  value = module.backend_app.backend_app_url
}

output "impulse_backend_app_fqdn" {
  value = module.backend_app.backend_app_fqdn
}

output "impulse_backend_identity_principal_id" {
  value = module.backend_app.backend_identity_principal_id
}

output "impulse_ai_app_url" {
  value = module.ai_app.ai_app_url
}

output "impulse_ai_app_fqdn" {
  value = module.ai_app.ai_app_fqdn
}

output "impulse_ai_identity_principal_id" {
  value = module.ai_app.ai_identity_principal_id
}

output "impulse_aca_env_id" {
  value = module.backend_app.aca_env_id
}

output "impulse_frontend_hostname" {
  value = module.frontend.frontend_default_hostname
}

output "impulse_log_analytics_workspace_name" {
  value = module.monitoring.log_analytics_workspace_name
}