output "client_id" {
  description = "Client ID of the managed identity (used in the service account annotation)."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "principal_id" {
  description = "Object ID of the managed identity."
  value       = azurerm_user_assigned_identity.this.principal_id
}
