resource "azurerm_log_analytics_workspace" "this" {
  name                         = var.name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = "PerGB2018"
  retention_in_days            = 30
  daily_quota_gb               = 1
  local_authentication_enabled = false
  tags                         = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}
