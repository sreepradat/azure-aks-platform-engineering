variable "name" {
  description = "Registry name. Globally unique, 5-50 lowercase alphanumeric characters."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that hosts the registry."
  type        = string
}

variable "sku" {
  description = "Registry SKU: Basic, Standard or Premium."
  type        = string
  default     = "Basic"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
