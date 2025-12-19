output "ai_app_id" {
  description = "Resource ID of the AI Azure Container App"
  value       = azurerm_container_app.ai.id
}

output "ai_app_name" {
  description = "Name of the AI Azure Container App"
  value       = azurerm_container_app.ai.name
}

output "ai_app_fqdn" {
  description = "FQDN of the AI Container App ingress (if enabled)"
  value       = try(azurerm_container_app.ai.ingress[0].fqdn, null)
}

output "ai_app_url" {
  description = "Public URL of the AI Container App (if ingress enabled)"
  value       = try("https://${azurerm_container_app.ai.ingress[0].fqdn}", null)
}

output "ai_identity_principal_id" {
  description = "Principal ID of the AI managed identity (User-Assigned)"
  value       = azurerm_user_assigned_identity.ai_app.principal_id
}

output "ai_identity_tenant_id" {
  description = "Tenant ID of the AI managed identity (User-Assigned)"
  value       = azurerm_user_assigned_identity.ai_app.tenant_id
}
