terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Configuration is supplied at init time: see backend.hcl.example and the README.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
