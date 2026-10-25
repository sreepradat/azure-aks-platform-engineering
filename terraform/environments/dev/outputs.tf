data "azurerm_client_config" "current" {}

output "resource_group_name" {
  description = "Resource group that contains the environment."
  value       = azurerm_resource_group.this.name
}

output "aks_name" {
  description = "Name of the AKS cluster."
  value       = module.aks.name
}

output "acr_name" {
  description = "Name of the container registry."
  value       = module.acr.name
}

output "acr_login_server" {
  description = "Login server of the container registry."
  value       = module.acr.login_server
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = module.keyvault.name
}

output "workload_identity_client_id" {
  description = "Client ID of the workload identity used by the sample app."
  value       = module.workload_identity.client_id
}

output "tenant_id" {
  description = "Microsoft Entra tenant ID."
  value       = data.azurerm_client_config.current.tenant_id
}
