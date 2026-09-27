output "id" {
  description = "ID of the Foundry account for its APIM role assignment."
  value       = azurerm_cognitive_account.this.id
}

output "endpoint" {
  description = "Regional Foundry inference endpoint."
  value       = azurerm_cognitive_account.this.endpoint
}
