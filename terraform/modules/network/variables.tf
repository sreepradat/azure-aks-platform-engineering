variable "name_prefix" {
  description = "Prefix used to name network resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that hosts the network."
  type        = string
}

variable "address_space" {
  description = "Address space of the virtual network."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "CIDR prefix of the subnet used by the AKS nodes."
  type        = string
  default     = "10.10.0.0/22"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
