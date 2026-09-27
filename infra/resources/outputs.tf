output "resource_group_id" {
  description = "ID of the resource group used by the demo services."
  value       = module.resource_group.id
}

output "primary_foundry_endpoint" {
  description = "Endpoint of the primary Foundry model account."
  value       = module.foundry_primary.endpoint
}

output "secondary_foundry_endpoint" {
  description = "Endpoint of the secondary Foundry model account."
  value       = module.foundry_secondary.endpoint
}

output "apim_gateway_url" {
  description = "API Management gateway URL; API paths are configured separately."
  value       = module.api_management.gateway_url
}

output "copilot_base_url" {
  description = "OpenAI-compatible base URL for the Copilot provider."
  value       = module.api_management.openai_base_url
}
