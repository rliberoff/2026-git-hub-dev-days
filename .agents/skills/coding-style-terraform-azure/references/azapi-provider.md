# `azapi` Provider Usage

Use the `azapi` provider when `azurerm` lacks support for new Azure features or resource types.

## When to Use `azapi`

| Scenario                     | Provider  | Example                                  |
| ---------------------------- | --------- | ---------------------------------------- |
| Standard Azure resources     | `azurerm` | Storage accounts, VNets, App Services    |
| New/preview features         | `azapi`   | RAI policies, dynamic throttling         |
| Unsupported resource types   | `azapi`   | Cutting-edge cognitive services features |
| Updating specific properties | `azapi`   | Post-deployment configuration changes    |

## Provider Configuration

Configure both providers together:

```terraform
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.32.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.4.0"
    }
  }
}
```

## Creating Resources with `azapi_resource`

Use `azapi_resource` for resource types not yet in `azurerm`. Always reference the Azure REST API specification for the correct schema:

```terraform
resource "azapi_resource" "content_filter" {
  type      = "Microsoft.CognitiveServices/accounts/raiPolicies@2024-10-01"
  name      = "CustomPolicy"
  parent_id = azurerm_cognitive_account.openai.id

  # Disable schema validation for preview APIs if needed
  schema_validation_enabled = false

  # Reference: https://github.com/Azure/azure-rest-api-specs
  body = {
    properties = {
      mode           = "Default"
      basePolicyName = "Microsoft.DefaultV2"
      contentFilters = [
        { name = "Violence", blocking = true, enabled = true, severityThreshold = "High", source = "Prompt" },
        { name = "Hate", blocking = true, enabled = true, severityThreshold = "High", source = "Prompt" },
        # Order matters - maintain consistent ordering to prevent drift
      ]
    }
  }
}
```

## Updating Existing Resources with `azapi_update_resource`

Use `azapi_update_resource` to modify properties on resources created by `azurerm`:

```terraform
resource "azapi_update_resource" "enable_dynamic_throttling" {
  for_each = { for model in var.models : model.id => model }

  type      = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01"
  parent_id = azurerm_cognitive_account.openai.id
  name      = each.value.model_name

  body = {
    properties = {
      dynamicThrottlingEnabled = true
      versionUpgradeOption     = "OnceNewDefaultVersionAvailable"
    }
  }

  depends_on = [azurerm_cognitive_deployment.openai]
}
```

## Best Practices for `azapi`

- **Always include API version** in the `type` attribute (e.g., `@2024-10-01`)
- **Reference Azure REST API specs** for correct property names and structures
- **Document the reason** for using `azapi` over `azurerm` in comments
- **Use `depends_on`** to ensure proper ordering with `azurerm` resources
- **Maintain array ordering** in body properties to prevent unnecessary updates
- **Set `schema_validation_enabled = false`** for preview APIs with incomplete schemas
