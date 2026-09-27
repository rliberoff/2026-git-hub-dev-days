output "gateway_url" {
  value = azurerm_api_management.this.gateway_url
}

output "openai_base_url" {
  value = "${trimsuffix(azurerm_api_management.this.gateway_url, "/")}/${azurerm_api_management_api.openai.path}"
}
