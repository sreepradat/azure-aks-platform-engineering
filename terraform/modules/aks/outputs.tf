output "id" {
  description = "Resource ID of the cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "name" {
  description = "Name of the cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL used for workload identity federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}
