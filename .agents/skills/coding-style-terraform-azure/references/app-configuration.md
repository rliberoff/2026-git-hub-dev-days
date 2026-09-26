# Application Configuration

Patterns for centralizing multi-service configuration in Azure App Configuration with Key Vault references, and for organizing it in `settings_*.tf` files.

## Application Configuration Patterns

When building multi-service applications, use Azure App Configuration with Key Vault references for centralized configuration management.

### Label-Based Service Configuration

Organize configurations by service using labels. Each service has its own configuration structure with direct values and Key Vault references:

```terraform
locals {
  # Configuration for a specific service
  api_service_config = {
    label = "MyApp.Services.Api"

    # Direct configuration values
    values = {
      "Sentinel"                     = 1
      "AllowedHosts"                 = "*"
      "CacheOptions:ExpirationHours" = "24"
      "DatabaseOptions:MaxRetries"   = "3"
    }

    # References to secrets stored in Key Vault
    keyvault_references = {
      "DatabaseOptions:ConnectionString" = "database-connectionstring"
      "ApiOptions:ApiKey"                = "external-api-key"
    }
  }

  # Shared configuration without label
  common_config = {
    label = ""
    values = {
      "Logging:LogLevel:Default" = "Information"
    }
    keyvault_references = {}
  }
}
```

### Aggregating Multi-Service Configurations

Use nested `for` loops with `flatten()` to aggregate configurations from all services into a single collection for the App Configuration module:

```terraform
locals {
  # Map of all services
  services = {
    common  = local.common_config
    api     = local.api_service_config
    worker  = local.worker_service_config
  }

  # Flatten all values across services
  app_config_values = flatten([
    for service_name, service in local.services : [
      for key, value in service.values : {
        label = service.label
        key   = key
        value = value
      }
    ]
  ])

  # Flatten all Key Vault references across services
  app_config_keyvault_refs = flatten([
    for service_name, service in local.services : [
      for key, secret_name in service.keyvault_references : {
        label       = service.label
        key         = key
        vault_name  = module.kv.name
        secret_name = secret_name
      }
    ]
  ])
}
```

### App Configuration Module Integration

Pass the aggregated configurations to the App Configuration module:

```terraform
module "appcs" {
  source   = "./modules/appcs"
  name     = "appcs-myapp-${var.environment}"
  # ... other configuration
  values   = local.app_config_values
  secrets  = local.app_config_keyvault_refs
}
```

The module iterates over these collections using `for_each`:

```terraform
resource "azurerm_app_configuration_key" "secrets" {
  for_each = { for s in var.secrets : "${s.label}|${s.key}" => s }

  configuration_store_id = azurerm_app_configuration.appcs.id
  key                    = each.value.key
  label                  = each.value.label
  type                   = "vault"
  vault_key_reference    = "https://${each.value.vault_name}.vault.azure.net/secrets/${each.value.secret_name}"
}

resource "azurerm_app_configuration_key" "values" {
  for_each = { for v in var.values : "${v.label}|${v.key}" => v }

  configuration_store_id = azurerm_app_configuration.appcs.id
  key                    = each.value.key
  label                  = each.value.label
  value                  = each.value.value
  type                   = "kv"
}
```

## Settings Files Organization

For complex multi-service infrastructures, organize configuration into separate settings files to improve maintainability.

### File Naming Convention

Use the pattern `settings_<component>.tf` for configuration-focused files:

| File                    | Purpose                                         |
| ----------------------- | ----------------------------------------------- |
| `settings_common.tf`    | Shared configuration values across all services |
| `settings_secrets.tf`   | Centralized secrets mapping to Key Vault        |
| `settings_<service>.tf` | Per-service App Configuration values            |

### Structure Example

```text
resources/
├── main.tf                    # Core resource definitions and module calls
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── providers.tf               # Provider configuration
├── settings_common.tf         # Shared config (logging, telemetry)
├── settings_secrets.tf        # Secrets aggregation
├── settings_api.tf            # API service configuration
├── settings_worker.tf         # Worker service configuration
└── modules/
```

### Settings Files Content Pattern

**settings_common.tf** - Shared values without service label:

```terraform
locals {
  common_config = {
    label = ""
    values = {
      "Logging:LogLevel:Default"   = "Information"
      "Logging:LogLevel:Microsoft" = "Warning"
    }
    keyvault_references = {}
  }
}
```

**settings_secrets.tf** - Centralized secrets mapping:

```terraform
locals {
  secrets = {
    # Secrets from module outputs
    "database-connectionstring" = module.cosmos.connection_string
    "storage-connectionstring"  = module.st.connection_string
    "openai-key"                = module.openai.key

    # Secrets from input variables
    "external-api-key" = var.external_api_key
  }
}
```

**settings\_\<service\>.tf** - Per-service configuration:

```terraform
locals {
  api_service_config = {
    label = "MyApp.Services.Api"
    values = {
      "ServiceOptions:Endpoint" = module.cosmos.endpoint
      # ... service-specific values
    }
    keyvault_references = {
      "ConnectionStrings:Database" = "database-connectionstring"
    }
  }
}
```
