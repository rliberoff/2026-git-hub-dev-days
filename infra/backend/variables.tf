variable "subscription_id" {
  description = "(Required) The Azure subscription ID where resources will be provisioned. This value must be provided and cannot be null."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.subscription_id)) > 0
    error_message = "The subscription_id must be a non-empty string."
  }
}

variable "location" {
  description = "(Optional) Azure region of the state store. Defaults to 'westeurope'."
  type        = string
  nullable    = false
  default     = "westeurope"
}


variable "resource_group_name" {
  description = "(Optional) The name of the resource group for the backend store. Defaults to rg-<project>-terraform when omitted."
  type        = string
  nullable    = false
  default     = "rg-squad-foundry-demo-state"
}

variable "storage_account_name" {
  description = "(Optional) The name of the storage account for the backend store. Defaults to sa-<project>-terraform when omitted."
  type        = string
  nullable    = false
  default     = "stsquadfoundrydemostate"
}

variable "tags" {
  description = "(Optional) Specifies tags for all the resources."
  type        = map(string)
  nullable    = false
  default = {
    createdUsing = "Terraform"
  }
}
