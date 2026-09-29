terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name = "rg-portfolio-tfstate"
    container_name      = "tfstate"
    key                 = "portfolio-prod.tfstate"
    use_azuread_auth    = true
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}
