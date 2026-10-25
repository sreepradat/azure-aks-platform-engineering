resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  base_name = "${var.project}-${var.environment}"
  suffix    = random_string.suffix.result

  tags = merge(
    {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    },
    var.extra_tags,
  )
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.base_name}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../../modules/network"

  name_prefix         = local.base_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

module "acr" {
  source = "../../modules/acr"

  name                = "acr${var.project}${var.environment}${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

module "aks" {
  source = "../../modules/aks"

  name                = "aks-${local.base_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.aks_subnet_id
  acr_id              = module.acr.id
  node_vm_size        = var.node_vm_size
  node_min_count      = var.node_min_count
  node_max_count      = var.node_max_count
  tags                = local.tags
}

module "keyvault" {
  source = "../../modules/keyvault"

  name                = "kv-${var.project}-${var.environment}-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

module "workload_identity" {
  source = "../../modules/workload-identity"

  name                 = "id-${local.base_name}-app"
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  oidc_issuer_url      = module.aks.oidc_issuer_url
  namespace            = var.kubernetes_namespace
  service_account_name = var.service_account_name
  key_vault_id         = module.keyvault.id
  tags                 = local.tags
}
