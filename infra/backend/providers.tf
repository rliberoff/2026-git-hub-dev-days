terraform {
  required_version = ">= 1.14"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.7.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {
    resource_group {
      # This flag is set to mitigate an open bug in Terraform.
      # For instance, the Resource Group is not deleted when a `Failure Anomalies` resource is present.
      # As soon as this is fixed, we should remove this.
      # Reference: https://github.com/hashicorp/terraform-provider-azurerm/issues/18026
      prevent_deletion_if_contains_resources = false
    }
  }
}

