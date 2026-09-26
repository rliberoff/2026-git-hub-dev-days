# Complex Validation Patterns

Use advanced validation techniques to enforce input constraints and prevent misconfigurations.

## Cross-Variable Validation

Validate that variable combinations are valid:

```terraform
variable "sku" {
  description = "The SKU tier. Possible values are Free, Standard, Premium."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Free, Standard, or Premium."
  }
}

variable "cost_analysis_enabled" {
  description = "Enable cost analysis. Requires Standard or Premium SKU."
  type        = bool
  default     = false

  validation {
    condition     = var.cost_analysis_enabled ? contains(["Standard", "Premium"], var.sku) : true
    error_message = "Cost analysis requires Standard or Premium SKU."
  }
}
```

## Array Uniqueness Validation

Ensure array elements have unique identifiers:

```terraform
variable "models" {
  description = "List of AI models to deploy."
  type = list(object({
    id            = string
    name          = string
    version       = string
    sku           = string
    capacity      = number
  }))

  validation {
    condition     = length(var.models) == length(distinct([for m in var.models : m.id]))
    error_message = "Each model ID must be unique."
  }
}
```

## Array Element Validation with `alltrue()`

Validate all elements in an array meet criteria:

```terraform
variable "models" {
  # ... type definition

  validation {
    condition = alltrue([
      for model in var.models : contains(
        ["Standard", "GlobalStandard", "ProvisionedManaged"],
        model.sku
      )
    ])
    error_message = "Invalid SKU. Allowed values: Standard, GlobalStandard, ProvisionedManaged."
  }
}
```

## Regex Pattern Validation

Use `can(regex())` for pattern matching:

```terraform
variable "resource_suffix" {
  description = "Suffix for resource names. Must be 3-8 lowercase alphanumeric characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,8}$", var.resource_suffix))
    error_message = "Suffix must be 3-8 lowercase alphanumeric characters."
  }
}
```

## Numeric Range Validation

Enforce minimum and maximum values:

```terraform
variable "node_count" {
  description = "Number of cluster nodes. Must be between 1 and 100."
  type        = number
  default     = 3

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 100
    error_message = "Node count must be between 1 and 100."
  }
}

variable "retention_days" {
  description = "Log retention in days. Must be 7, 30, 60, 90, or 365."
  type        = number
  default     = 30

  validation {
    condition     = contains([7, 30, 60, 90, 365], var.retention_days)
    error_message = "Retention must be 7, 30, 60, 90, or 365 days."
  }
}
```

## Conditional Required Values

Validate that dependent values are provided:

```terraform
variable "use_existing_resource" {
  description = "Whether to use an existing resource."
  type        = bool
  default     = false
}

variable "existing_resource_id" {
  description = "ID of existing resource. Required when use_existing_resource is true."
  type        = string
  default     = null

  validation {
    condition     = var.use_existing_resource ? var.existing_resource_id != null : true
    error_message = "existing_resource_id is required when use_existing_resource is true."
  }
}
```

## Multiple Validations Per Variable

Apply multiple validation blocks for comprehensive checks:

```terraform
variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition     = length(var.environment) >= 2 && length(var.environment) <= 10
    error_message = "Environment name must be 2-10 characters."
  }

  validation {
    condition     = can(regex("^[a-z]+$", var.environment))
    error_message = "Environment name must be lowercase letters only."
  }

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, test, staging, or prod."
  }
}
```
