terraform {
  required_version = ">= 1.14.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.7.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.9.1"
    }
  }
}

terraform {
  backend "azurerm" {}
}


provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    app_configuration {
      purge_soft_delete_on_destroy = true
    }
    key_vault {
      purge_soft_deleted_secrets_on_destroy = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
    resource_group {
      # This flag is set to mitigate an open bug in Terraform.
      # For instance, the Resource Group is not deleted when a `Failure Anomalies` resource is present.
      # As soon as this is fixed, we should remove this.
      # Reference: https://github.com/hashicorp/terraform-provider-azurerm/issues/18026
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {
}
