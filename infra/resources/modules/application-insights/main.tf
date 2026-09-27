resource "azurerm_application_insights" "this" {
  name                         = var.name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  application_type             = "other"
  workspace_id                 = var.workspace_id
  daily_data_cap_in_gb         = 1
  retention_in_days            = 30
  local_authentication_enabled = false
  tags                         = var.tags
}
