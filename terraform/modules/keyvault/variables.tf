variable "name" {
  description = "Key Vault name. Globally unique, 3-24 characters."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that hosts the vault."
  type        = string
}

variable "purge_protection_enabled" {
  description = "Enable purge protection. Keep false in dev so the environment can be destroyed cleanly."
  type        = bool
  default     = false
}

variable "demo_secret_value" {
  description = "Value of the demo secret mounted into the sample app."
  type        = string
  default     = "hello-from-azure-key-vault"
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
