output "aca_env_id" {
  description = "ID of the ACA environment (shared with AI app)"
  value       = azurerm_container_app_environment.aca_env.id
}

output "backend_app_id" {
  description = "Resource ID of the backend Azure Container App"
  value       = azurerm_container_app.backend.id
}

output "backend_app_name" {
  description = "Name of the backend Azure Container App"
  value       = azurerm_container_app.backend.name
}

output "backend_fqdn" {
  description = "FQDN of the backend Container App ingress (if enabled)"
  value       = try(azurerm_container_app.backend.ingress[0].fqdn, null)
}

output "backend_app_fqdn" {
  description = "Alias of backend_fqdn (kept for naming consistency)"
  value       = try(azurerm_container_app.backend.ingress[0].fqdn, null)
}

output "backend_app_url" {
  description = "Public URL of the backend Container App (if ingress enabled)"
  value       = try("https://${azurerm_container_app.backend.ingress[0].fqdn}", null)
}

output "backend_identity_principal_id" {
  description = "Principal ID of the backend managed identity (User-Assigned)"
  value       = azurerm_user_assigned_identity.backend_app.principal_id
}

output "backend_identity_tenant_id" {
  description = "Tenant ID of the backend managed identity (User-Assigned)"
  value       = azurerm_user_assigned_identity.backend_app.tenant_id
}
