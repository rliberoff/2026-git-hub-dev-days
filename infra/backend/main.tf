locals {
  tags = merge(var.tags, {
    createdAt  = "${formatdate("YYYY-MM-DD hh:mm:ss", timestamp())} UTC"
    createdFor = "TerraformRemoteState"
  })
}

resource "azurerm_resource_group" "terraform" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}

resource "azurerm_storage_account" "backend" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.terraform.name
  location                        = azurerm_resource_group.terraform.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.backend.id
  container_access_type = "private"
}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "terraform_state" {
  scope                = azurerm_storage_account.backend.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
