terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.8"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }

  backend "azurerm" {
    resource_group_name = "rg-portfolio-tfstate"
    container_name      = "tfstate"
    key                 = "portfolio-github.tfstate"
    use_azuread_auth    = true
  }
}

provider "github" {
  owner = "roofiq"
}

variable "subscription_id" {
  type = string
}

variable "state_storage_account_name" {
  type = string
}

variable "location" {
  description = "Region for the portfolio resource group. Site hosting has its own supported region."
  type        = string
  default     = "polandcentral"
}

provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.Web"]
}

provider "azuread" {}

data "azuread_client_config" "current" {}

data "azurerm_storage_account" "state" {
  name                = var.state_storage_account_name
  resource_group_name = "rg-portfolio-tfstate"
}

data "external" "github_oidc" {
  program = ["pwsh", "-NoProfile", "-File", "${path.module}/read-github-oidc.ps1"]
}

resource "azurerm_resource_group" "portfolio" {
  name     = "rg-portfolio-prod"
  location = var.location
}

resource "azuread_application" "terraform" {
  display_name     = "github-portfolio"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "terraform" {
  client_id = azuread_application.terraform.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "production" {
  application_id = azuread_application.terraform.id
  display_name   = "github-production"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "${data.external.github_oidc.result.prefix}:environment:${github_repository_environment.production.environment}"
}

resource "azurerm_role_assignment" "portfolio" {
  scope                = azurerm_resource_group.portfolio.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.terraform.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "state" {
  scope                = "${data.azurerm_storage_account.state.id}/blobServices/default/containers/tfstate"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.terraform.object_id
  principal_type       = "ServicePrincipal"
}

locals {
  production_variables = {
    AZURE_CLIENT_ID          = azuread_application.terraform.client_id
    AZURE_TENANT_ID          = data.azuread_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID    = var.subscription_id
    TF_STATE_STORAGE_ACCOUNT = var.state_storage_account_name
  }
}

resource "github_repository_environment" "production" {
  repository  = "portfolio"
  environment = "production"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "main" {
  repository     = github_repository_environment.production.repository
  environment    = github_repository_environment.production.environment
  branch_pattern = "main"
}

resource "github_actions_environment_variable" "azure" {
  for_each = local.production_variables

  repository    = github_repository_environment.production.repository
  environment   = github_repository_environment.production.environment
  variable_name = each.key
  value         = each.value
}
