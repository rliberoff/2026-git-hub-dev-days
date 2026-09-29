# The following outputs are used to set environment variables consumed by The Azure Developer CLI (`azd`) for configuring the Terraform backend.
# They are emitted here in the backend layer since they depend on the resources provisioned in this layer, but they are consumed by `azd` during the deployment of the resources in the resources layer.
# Emitting them here allows us to set up the `azd` environment as soon as the backend layer is deployed, so that it's ready to be consumed by the resources layer when it gets deployed.

output "RS_STORAGE_ACCOUNT" {
  description = "Name of the storage account used by azd for container builds and pushes."
  value       = azurerm_storage_account.backend.name
}

output "RS_CONTAINER_NAME" {
  description = "Name of the storage container used by azd for container builds and pushes."
  value       = azurerm_storage_container.tfstate.name
}

output "RS_RESOURCE_GROUP" {
  description = "Name of the resource group used by azd for container builds and pushes."
  value       = azurerm_resource_group.terraform.name
}
