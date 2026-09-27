output "id" {
  value = azurerm_application_insights.this.id
}

output "connection_string" {
  sensitive = true
  value     = azurerm_application_insights.this.connection_string
}
