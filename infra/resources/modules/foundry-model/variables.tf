variable "name" {
  description = "Required globally unique Foundry account name."
  type        = string
  nullable    = false
}

variable "location" {
  description = "Required Azure region for the account and model."
  type        = string
  nullable    = false
}

variable "resource_group_name" {
  description = "Required resource group containing the account."
  type        = string
  nullable    = false
}

variable "model_deployments" {
  description = "(Required) Fixed model deployment configuration for the Microsoft Foundry account."
  type = list(object({
    deployment_name = string
    model_name      = string
    model_version   = string
    sku_name        = string
    capacity        = number
  }))
  nullable = false

  validation {
    condition     = length(var.model_deployments) == length(distinct([for model in var.model_deployments : model.deployment_name]))
    error_message = "Each model deployment name must be unique."
  }

  validation {
    condition     = alltrue([for model in var.model_deployments : contains(["Standard", "DataZoneBatch", "DataZoneStandard", "DataZoneProvisionedManaged", "GlobalBatch", "GlobalProvisionedManaged", "GlobalStandard", "ProvisionedManaged"], model.sku_name)])
    error_message = "The SKU name is invalid. Check the valid values for the deployed model."
  }
}

variable "tags" {
  description = "Required Azure resource tags."
  type        = map(string)
  nullable    = false
}
