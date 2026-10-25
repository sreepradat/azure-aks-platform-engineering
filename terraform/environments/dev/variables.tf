variable "subscription_id" {
  description = "Azure subscription ID. When null, the ARM_SUBSCRIPTION_ID environment variable is used."
  type        = string
  default     = null
}

variable "project" {
  description = "Short project name used in resource names (lowercase alphanumeric)."
  type        = string
  default     = "aksplat"
}

variable "environment" {
  description = "Environment name used in resource names."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "centralindia"
}

variable "kubernetes_namespace" {
  description = "Namespace the sample app is deployed to."
  type        = string
  default     = "sample-app"
}

variable "service_account_name" {
  description = "Kubernetes service account used by the sample app."
  type        = string
  default     = "sample-app"
}

variable "node_vm_size" {
  description = "VM size of the AKS system node pool. Change it if your subscription has no quota for it."
  type        = string
  default     = "Standard_B2s"
}

variable "node_min_count" {
  description = "Minimum number of AKS nodes."
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum number of AKS nodes."
  type        = number
  default     = 2
}

variable "extra_tags" {
  description = "Additional tags merged into the default tag set."
  type        = map(string)
  default     = {}
}
