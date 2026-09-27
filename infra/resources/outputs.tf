output "resource_group_id" {
  description = "ID of the resource group used by the demo services."
  value       = module.resource_group.id
}

output "resource_group_name" {
  description = "Name of the resource group used by the demo services."
  value       = module.resource_group.name
}

output "primary_foundry_endpoint" {
  description = "Endpoint of the primary Foundry model account."
  value       = module.foundry_primary.endpoint
}

output "primary_region" {
  description = "Azure region hosting the primary Foundry model account."
  value       = var.primary_region
}

output "secondary_foundry_endpoint" {
  description = "Endpoint of the secondary Foundry model account."
  value       = module.foundry_secondary.endpoint
}

output "secondary_region" {
  description = "Azure region hosting the secondary Foundry model account."
  value       = var.secondary_region
}

output "apim_gateway_url" {
  description = "API Management gateway URL; API paths are configured separately."
  value       = module.api_management.gateway_url
}

output "apim_name" {
  description = "Name of the API Management service."
  value       = module.api_management.name
}

output "apim_primary_backend_url" {
  description = "URL configured for the primary Foundry backend, used to assert the failover test baseline."
  value       = module.api_management.primary_backend_url
}

output "copilot_base_url" {
  description = "OpenAI-compatible base URL for the Copilot provider."
  value       = module.api_management.openai_base_url
}
