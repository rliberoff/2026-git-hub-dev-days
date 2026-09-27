resource "azurerm_cognitive_account" "this" {
  name                  = var.name
  location              = var.location
  resource_group_name   = var.resource_group_name
  kind                  = "AIServices"
  sku_name              = "S0"
  custom_subdomain_name = var.name
  local_auth_enabled    = false
  tags                  = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_cognitive_deployment" "foundry" {
  for_each = { for model in var.model_deployments : model.deployment_name => model }

  name                 = each.key
  cognitive_account_id = azurerm_cognitive_account.this.id

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.model_version
  }

  sku {
    capacity = each.value.capacity
    name     = each.value.sku_name
  }
}
