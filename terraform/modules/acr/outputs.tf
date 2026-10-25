output "id" {
  description = "Resource ID of the registry."
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "Name of the registry."
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Login server of the registry, for example myacr.azurecr.io."
  value       = azurerm_container_registry.this.login_server
}
