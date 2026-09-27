variable "subscription_id" {
  description = "Required Azure subscription ID for this demo."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid GUID."
  }
}

variable "use_random_suffix" {
  description = "(Required) If `true`, a random suffix is generated and added to the resource groups and its resources. If `false`, the `suffix` variable is used instead."
  type        = bool
  nullable    = false
  default     = true
}

variable "suffix" {
  description = "(Optional) A suffix for the name of the resource group and its resources. If variable `use_random_suffix` is `true`, this variable is ignored."
  type        = string
  nullable    = false
  default     = ""
}

variable "resource_group_name" {
  description = "(Optional)Required name of the demo resource group."
  type        = string
  nullable    = false
  default     = "rg-squad-foundry-demo"

  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0
    error_message = "resource_group_name must not be empty."
  }
}

variable "primary_region" {
  description = "(Optional) Required Azure region for the resource group and primary model deployment."
  type        = string
  nullable    = false
  default     = "francecentral"

  validation {
    condition     = length(trimspace(var.primary_region)) > 0
    error_message = "primary_region must not be empty."
  }
}

variable "secondary_region" {
  description = "(Optional) Required Azure region for the secondary model deployment."
  type        = string
  nullable    = false
  default     = "switzerlandnorth"

  validation {
    condition     = length(trimspace(var.secondary_region)) > 0 && var.secondary_region != var.primary_region
    error_message = "secondary_region must be nonempty and different from primary_region."
  }
}

variable "foundry_primary_name" {
  description = "(Optional)Required globally unique name of the primary Foundry account."
  type        = string
  nullable    = false
  default     = "ai-squad-foundry-demo-primary"
}

variable "foundry_secondary_name" {
  description = "(Optional) Required globally unique name of the secondary Foundry account."
  type        = string
  nullable    = false
  default     = "ai-squad-foundry-demo-secondary"

  validation {
    condition     = var.foundry_secondary_name != var.foundry_primary_name
    error_message = "The Foundry account names must be different."
  }
}

variable "foundry_model_deployments" {
  description = "(Required) Fixed model deployment configuration for the Microsoft Foundry account."
  type = list(object({
    deployment_name = string
    model_name      = string
    model_version   = string
    sku_name        = string
    capacity        = number
  }))
  nullable = false
  default = [
    {
      deployment_name = "gpt-5.6-sol"
      model_name      = "gpt-5.6-sol"
      model_version   = "2026-07-09"
      sku_name        = "GlobalStandard"
      capacity        = 10
    },
    {
      deployment_name = "gpt-5.6-terra"
      model_name      = "gpt-5.6-terra"
      model_version   = "2026-07-09"
      sku_name        = "GlobalStandard"
      capacity        = 10
    },
    {
      deployment_name = "gpt-5.6-luna"
      model_name      = "gpt-5.6-luna"
      model_version   = "2026-07-09"
      sku_name        = "GlobalStandard"
      capacity        = 10
    },
    {
      deployment_name = "gpt-5.4"
      model_name      = "gpt-5.4"
      model_version   = "2026-03-05"
      sku_name        = "GlobalStandard"
      capacity        = 10
    }
  ]

  validation {
    condition     = length(var.foundry_model_deployments) == length(distinct([for model in var.foundry_model_deployments : model.deployment_name]))
    error_message = "Each model deployment name must be unique."
  }

  validation {
    condition     = alltrue([for model in var.foundry_model_deployments : contains(["Standard", "DataZoneBatch", "DataZoneStandard", "DataZoneProvisionedManaged", "GlobalBatch", "GlobalProvisionedManaged", "GlobalStandard", "ProvisionedManaged"], model.sku_name)])
    error_message = "The SKU name is invalid. Check the valid values for the deployed model."
  }
}

variable "apim_name" {
  description = "Required globally unique API Management service name."
  type        = string
  nullable    = false
  default     = "apim-squad-foundry-demo"
}

variable "apim_publisher_name" {
  description = "Required name of the API Management publisher."
  type        = string
  nullable    = false
  default     = "Squad Foundry Demo"
}

variable "apim_publisher_email" {
  description = "Required email address of the API Management publisher."
  type        = string
  nullable    = false
  default     = "squad-foundry-demo@yopmail.com"

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+\\.[^@ ]+$", var.apim_publisher_email))
    error_message = "apim_publisher_email must be an email address."
  }
}

variable "apim_sku_name" {
  description = "Required API Management SKU and capacity, chosen with explicit cost approval."
  type        = string
  nullable    = false
  default     = "BasicV2_1"

  validation {
    condition     = contains(["Developer_1", "Basic_1", "Standard_1", "Premium_1", "BasicV2_1", "StandardV2_1", "PremiumV2_1"], var.apim_sku_name)
    error_message = "apim_sku_name must be a supported dedicated tier with one unit."
  }
}

variable "apim_tokens_per_minute" {
  description = "Maximum combined prompt and completion tokens per APIM subscription each minute."
  type        = number
  nullable    = false
  default     = 2000

  validation {
    condition     = var.apim_tokens_per_minute > 0 && floor(var.apim_tokens_per_minute) == var.apim_tokens_per_minute
    error_message = "apim_tokens_per_minute must be a positive integer."
  }
}

variable "log_analytics_name" {
  description = "Required name of the Log Analytics workspace for gateway telemetry."
  type        = string
  nullable    = false
  default     = "log-squad-foundry-demo"
}

variable "application_insights_name" {
  description = "Required name of the Application Insights component for gateway telemetry."
  type        = string
  nullable    = false
  default     = "appi-squad-foundry-demo"
}

variable "tags" {
  description = "(Optional) Specifies tags for all the resources."
  type        = map(string)
  nullable    = false
  default = {
    createdUsing = "Terraform"
  }
}
