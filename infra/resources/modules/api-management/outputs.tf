output "name" {
  value = azurerm_api_management.this.name
}

output "gateway_url" {
  value = azurerm_api_management.this.gateway_url
}

output "openai_base_url" {
  value = "${trimsuffix(azurerm_api_management.this.gateway_url, "/")}/${azurerm_api_management_api.openai.path}"
}

output "primary_backend_url" {
  value = azurerm_api_management_backend.foundry["primary"].url
}
