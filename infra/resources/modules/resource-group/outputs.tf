output "id" {
  description = "Resource group ID."
  value       = azurerm_resource_group.this.id
}

output "name" {
  description = "Resource group name."
  value       = azurerm_resource_group.this.name
}
