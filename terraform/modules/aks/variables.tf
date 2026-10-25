variable "name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that hosts the cluster."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet used by the node pool."
  type        = string
}

variable "acr_id" {
  description = "ID of the container registry the cluster pulls images from."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. Null lets Azure pick the current default."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "AKS control plane tier: Free or Standard."
  type        = string
  default     = "Free"
}

variable "node_vm_size" {
  description = "VM size of the system node pool."
  type        = string
  default     = "Standard_B2s"
}

variable "node_min_count" {
  description = "Minimum number of nodes (cluster autoscaler)."
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum number of nodes (cluster autoscaler)."
  type        = number
  default     = 2
}

variable "service_cidr" {
  description = "CIDR range for Kubernetes services. Must not overlap with the VNet."
  type        = string
  default     = "10.100.0.0/16"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
