---
name: coding-style-terraform-azure
description: 'Coding style conventions and best practices for writing Terraform (HCL) for Azure infrastructure with the azurerm and azapi providers. Use when creating, editing, reviewing, or validating Azure Terraform code (*.tf, *.tfvars, *.tf.json): modules, variables and validation, naming, tagging, managed identities, secrets and Key Vault, remote state, App Configuration settings files, azapi resources, and file-based data seeding.'
---

# Terraform for Azure Guidelines

Guidelines for generating Terraform code for Azure infrastructure following best practices, security standards, and compliance requirements.

## Project Context

- **Terraform Version**: 1.14+ with HCL syntax
- **Primary Providers**: `azurerm` (preferred), `azapi` for cutting-edge features
- **Provider Registry**: [registry.terraform.io](https://registry.terraform.io/)

## General Principles

- Use the Azure knowledge MCP tools (`microsoft_docs_search`, `microsoft_code_sample_search`) to ensure accuracy and best practices in Azure services.
- Use the Terraform MCP Server tools to generate the Terraform code to meet the refined requirements for Azure infrastructure.
- Refine all infrastructure requirements to be Azure-specific and aligned with best practices, security, and compliance standards.
- Keep the infrastructure stack lean and avoid unnecessary complexity.

## Core Rules

- Terraform should be written using HCL (HashiCorp Configuration Language) syntax.
- Ensure that the generated code is well-documented with comments explaining the purpose of each resource and configuration.
- Always try to use implicit dependencies over explicit dependencies where possible.
- When generating Terraform resource names, ensure they are unique and descriptive, lower-case, and snake_case.
- Be sure to include any necessary provider configurations, backend settings, and required variables in the generated code.
- Ensure the generated Terraform code always includes a top level `tags` variable map that is used on all taggable resources, with at least the following tags: `environment`, `project`, and `owner`.
- Ensure that sensitive information such as passwords, API keys, and secrets are not hardcoded. Use variables and values in `.tfvars` files instead.
- Do not assume any prior knowledge about the user's Azure environment; **always seek clarification when in doubt**.
- Before finalizing the Terraform code, always confirm with the user that all requirements have been accurately captured and addressed.
- Any sensitive information in output must be marked as `sensitive = true`.
- Always use the latest version of Terraform unless a specific version is defined or requested.
- Always search in the [Terraform Registry](https://registry.terraform.io/) for the latest provider versions.

## Anti-Patterns to Avoid

### Configuration Anti-Patterns

- **MUST NOT hardcode values** that should be parameterized (e.g., resource names, locations, SKUs).
- **SHOULD NOT use `terraform import`** as a regular workflow pattern. It's for one-time migrations only.
- **SHOULD avoid complex conditional logic** that makes code hard to understand and maintain.
- **MUST NOT use `local-exec` provisioners** unless absolutely necessary; prefer native resource configurations.
- **MUST NOT use `null_resource`** for triggers; use `terraform_data` instead.

### Security Anti-Patterns

- **MUST NEVER store secrets** in Terraform files (`.tf`) or state files.
- **MUST avoid overly permissive IAM roles** or network rules; follow principle of least privilege.
- **MUST NOT disable security features** for convenience (e.g., encryption, firewall rules).
- **MUST NOT use default passwords or keys**; always generate or parameterize credentials.
- **MUST NOT commit `.tfstate` files** or `.terraform/` directories to version control.

### Operational Anti-Patterns

- **MUST only use state files (`*.tfstate`) for read-only operations**; all changes via Terraform CLI or HCL.
- **MUST only use contents of `.terraform/` directory** (fetched modules and providers) for read-only operations.
- **MUST avoid creating separate folders/repos/branches per environment**; use `.tfvars` files for environment differences.

## Provider Selection

- **Use `azurerm` provider** for most scenarios – it offers high stability and covers the majority of Azure services
- **Use `azapi` provider** when `azurerm` lacks support (see [references/azapi-provider.md](references/azapi-provider.md) for details)
- **Document the choice** in code comments when using `azapi`
- Only use official or certified providers:
  - `hashicorp/azuread` for Microsoft Entra ID (former Azure Active Directory) resources
  - `hashicorp/helm` for Helm chart deployments
  - `hashicorp/kubernetes` for Kubernetes resources
  - `hashicorp/random` for random ID generation

## Project Structure and Organization

### Modular Architecture

Use Terraform modules to group reusable infrastructure components. For any resource set that will be used in multiple contexts:

- Create a module with its own variables and outputs
- Reference it rather than duplicating code
- This promotes reuse and consistency
- **Separate modules by resource type**: Each Azure resource type has its own module directory (e.g., `modules/aca/`, `modules/kv/`, `modules/oai/`, `modules/cosmos/`, `modules/acr/`, etc.)

### Organize Code Cleanly

Structure Terraform configurations with logical file separation:

- **Consistent module structure**: Each module contains:
  - `main.tf` - Resource definitions
  - `variables.tf` - Input variables
  - `outputs.tf` - Output values, including sensitive information when required.
  - `providers.tf` - Provider configuration when needed.
- Follow consistent naming conventions and formatting.

### Backend Configuration

- **Separate backend infrastructure**: Backend state storage (`backend/`) is isolated from main resources (`resources/`)
- **Remote state management**: Use Azure Storage Account for Terraform state with proper configuration

## Naming Conventions

### Resource Naming

- **Consistent prefix pattern**: Use Azure resource abbreviations (e.g., `rg-`, `acr`, `appcs-`, `kv-`, `appi-`)
- **Suffix strategy with locals**: Compute resource names with suffixes in locals block, allowing multiple deployments without collisions
- **Random suffix option**: Provide flexibility between random and fixed suffixes via variables
- **Module folders or directory names**: Use kebab-case for module folder names using the same abbreviation strategy

  ```terraform
  locals {
    suffix = lower(trimspace(var.use_random_suffix ? substr(lower(random_id.random.hex), 1, 5) : var.suffix))
    name_resource_group = "${var.resource_group_name}-${local.suffix}"
    name_acr = "${var.acr_name}${local.suffix}"
  }
  ```

### Variable Naming

- **Descriptive prefixes**: Group related variables by resource type (e.g., `aca_bot_*`, `appcs_*`, `openai_*`)
- **Underscores for readability**: Use snake_case for all identifiers

## Variable Management

### Variable Documentation

- **Comprehensive descriptions**: Every variable includes:
  - Required/Optional status (i.e., is nullable or not)
  - Purpose and impact
  - Default values if applicable
  - External references (e.g., Azure documentation links)

### Variable Validation

- **Built-in validation blocks**: Always validate input values at the variable level
- **See [references/validation-patterns.md](references/validation-patterns.md)** for comprehensive validation techniques including:
  - Regex validation with `can(regex())`
  - Range and numeric validation
  - Array uniqueness and element validation
  - Cross-variable validation
  - Conditional required values

### Variable Defaults

- **Parameterize** all configurable values using variables with types and descriptions
- **Sensible defaults**: Provide production-ready defaults (e.g., `location = "swedencentral"`)
- **Explicit nullability**: Use `nullable = false` to enforce required values

## Tagging Strategy

### Consistent Tagging

- **Centralized tag management**: Define common tags in locals:

  ```terraform
  locals {
    tags = merge(var.tags, {
      environment = var.environment
      project     = var.project
      owner       = var.owner
      createdAt   = "${formatdate("YYYY-MM-DD hh:mm:ss", timestamp())} UTC"
      createdWith = "Terraform"
      suffix      = local.suffix
    })
  }
  ```

- **Automatic metadata**: Include creation timestamp and tool information
- **Tag inheritance**: Pass tags to all modules and resources

### Tag Lifecycle

- **Ignore tag changes**: Prevent drift from external tag modifications:

  ```terraform
  lifecycle {
    ignore_changes = [tags]
  }
  ```

## Resource Configuration

### Identity Management

- **User-assigned managed identities**: Prefer user-assigned over system-assigned for flexibility:

  ```terraform
  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }
  ```

- **Consistent identity passing**: Pass managed identity to all resources requiring authentication

### Data Sources

- **Current configuration retrieval**: Use data sources for runtime information:

  ```terraform
  data "azurerm_client_config" "current" {}
  data "azurerm_subscription" "current" {}
  data "azuread_user" "current_user" {
    object_id = data.azurerm_client_config.current.object_id
  }
  ```

### Dynamic Blocks

- **Conditional resource creation**: Use `dynamic` blocks for optional configurations:

  ```terraform
  dynamic "geo_location" {
    for_each = var.geo_locations
    content {
      location          = geo_location.value.location
      failover_priority = geo_location.value.failover_priority
    }
  }
  ```

## Lifecycle Management

### Prevent Unwanted Updates

- For Azure, always ignore changes to `tags`.
- **Selective ignore_changes**: Ignore attributes managed externally:

  ```terraform
  lifecycle {
    ignore_changes = [
      tags,
      template[0].container[0].image,
    ]
  }
  ```

### Trigger-Based Replacement

- **Content-based triggers**: Use `terraform_data` with SHA1 hashing to detect actual file changes:

  ```terraform
  resource "terraform_data" "trigger_update_bot_icon" {
    input = sha1(file_content)
  }

  lifecycle {
    replace_triggered_by = [terraform_data.trigger_update_bot_icon]
  }
  ```

## Security Practices

### Access Control

- **Role-based access**: Define role assignments for managed identities:

  ```terraform
  resource "azurerm_role_assignment" "service_principals_role_assignment" {
    scope                = azurerm_cognitive_account.openai.id
    role_definition_name = "Cognitive Services OpenAI User"
    principal_id         = each.value
  }
  ```

### Secrets Management

- **The best secret is one that does not need to be stored**: Use Managed Identities rather than passwords or keys whenever possible
- **No hardcoded secrets**: Use variables for sensitive values
- **Ephemeral secrets (Terraform v1.11+)**: Use `ephemeral` secrets with write-only parameters to avoid storing secrets in state files:

  ```terraform
  ephemeral "azurerm_key_vault_secret" "admin_password" {
    name         = "admin-password"
    key_vault_id = azurerm_key_vault.main.id
  }

  resource "azurerm_virtual_machine" "example" {
    # ... other configuration
    admin_password = ephemeral.azurerm_key_vault_secret.admin_password.value
  }
  ```

- **When sensitive data or secrets are provided** as part of the development, put them in a `terraform.tfvars` file linked to their corresponding variable
- **Key Vault integration**: Store secrets in Azure Key Vault with proper access policies unless directed to use a different service
- **Name sanitization**: Replace unsupported characters (e.g., `:` to `--` for Key Vault secret names)
- **Never write secrets** to local filesystems or commit to git
- **Mark sensitive values appropriately**: Isolate them from other attributes and avoid outputting sensitive data unless absolutely necessary

## Development Modes

### Environment-Specific Configuration

- **Development mode flag**: Use boolean flag for dev-specific configurations:

  ```terraform
  variable "development_mode" {
    description = "Specifies whether this resource should be created with configurations suitable for development purposes."
    type        = bool
    default     = false
  }
  ```

- **Conditional resource creation**: Use `count` with development mode for dev-only resources:

  ```terraform
  data "azurerm_client_config" "current" {
    count = var.development_mode ? 1 : 0
  }
  ```

## Provider Configuration

### Version Pinning

- **Pessimistic version constraints**: Use `~>` for patch-level flexibility:

  ```terraform
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.2.0"
    }
  }
  ```

### Provider Features

- **Bug mitigation flags**: Document workarounds with references:

  ```terraform
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  ```

## Module Usage

### Dependency Management

- **Implicit dependencies**: Rely on and prefer Terraform's built-in dependency graph where possible
- **Explicit dependencies**: Use `depends_on` only when implicit dependencies aren't sufficient
- **Redundant depends_on Detection**: Search and remove `depends_on` where the dependent resource is already referenced implicitly in the same resource block:

  ```terraform
  # BAD: Redundant depends_on
  resource "azurerm_subnet" "example" {
    name                 = "subnet-example"
    virtual_network_name = azurerm_virtual_network.example.name  # Implicit dependency
    resource_group_name  = azurerm_resource_group.example.name
    depends_on           = [azurerm_virtual_network.example]    # REDUNDANT!
  }

  # GOOD: Only implicit dependency
  resource "azurerm_subnet" "example" {
    name                 = "subnet-example"
    virtual_network_name = azurerm_virtual_network.example.name  # Implicit dependency is sufficient
    resource_group_name  = azurerm_resource_group.example.name
  }

  # ACCEPTABLE: Explicit dependency when needed
  module "aca_bot_backend" {
    depends_on = [module.acr]  # Module dependency, no implicit reference
    # ... configuration
  }
  ```

- **Never depend on module outputs**: Module outputs create implicit dependencies; explicit `depends_on` is unnecessary

### Module Reusability

- **Use `for_each` for multiple instances**: Create multiple similar resources efficiently:

  ```terraform
  resource "azurerm_cognitive_deployment" "openai" {
    for_each = { for model in var.models : model.id => model }
    # ... configuration
  }
  ```

## Output Management

### Informative Outputs

- **Use outputs** to expose key resource attributes for other modules or user reference.
- **Mark sensitive values** accordingly to protect secrets.
- **Clear descriptions**: Every output has a descriptive explanation.
- **Helper messages**: Include example commands in outputs:

  ```terraform
  output "terraform_init_backend" {
    description = "Shows an example of the Terraform command to initialize a deployment with this backend."
    value       = local.terraform_message
  }
  ```

## Documentation and Comments

### Inline Documentation

- **Complex logic explanations**: Add detailed comments for non-obvious implementations
- **Bug workaround references**: Document known issues with GitHub/Azure issue links
- **Multi-line comment blocks**: Use for detailed explanations of lifecycle rules and special cases

### Code Comments

- **Purpose explanation**: Clarify why certain approaches are taken
- **External references**: Link to official documentation for validation

## File Organization

### Separation of Concerns

- **Split variables by resource**: Use separate variable files when complexity warrants
- **Use `settings_*.tf` files**: For multi-service App Configuration patterns (see [references/app-configuration.md](references/app-configuration.md))
- **Logical grouping**: Group related configurations together

### Regarding `.tfvars` Files

- **Environment-specific values**: Use `.tfvars` files for environment configuration
- **Use tfvars to modify environmental differences**: Aim to keep environments similar whilst cost optimizing for non-production
- **Comments in tfvars**: Document non-obvious values directly in variable files

### Folder Structure Best Practices

Use a consistent folder structure. A suggested structure (never change without user agreement):

```text
my-azure-app/
├── infra/                          # Terraform root module
│   ├── main.tf                     # Core resources
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Outputs
│   ├── providers.tf                # Provider configuration
│   ├── environments/               # Environment-specific configurations
│   │   ├── dev.tfvars              # Development environment
│   │   ├── test.tfvars             # Test environment
│   │   └── prod.tfvars             # Production environment
│   └── modules/                    # Reusable modules
│       ├── kv/                     # Key Vault module
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── acr/                    # Container Registry module
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── app/                    # App Service module
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── oai/                    # OpenAI/Cognitive Services module
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── .github/workflows/              # CI/CD pipelines
└── README.md                       # Documentation
```

**Anti-pattern**: Avoid branch-per-environment, repository-per-environment, or folder-per-environment layouts that make it hard to test root folder logic between environments

## Testing and Validation

### Pre-Validation Steps

- **Inventory existing resources**: Do an inventory of existing resources and offer to remove unused resource blocks
- **Code review**: Check for anti-patterns, redundant dependencies, and security issues

### Terraform Commands

- **Terraform validate**: Always ensure generated code passes `terraform validate` to check syntax
- **Ask before running plan**: Run `terraform plan` only with explicit user permission
- **Subscription ID**: When running `terraform plan`, source the subscription ID (`subscription_id`) from the `ARM_SUBSCRIPTION_ID` environment variable or ask the user for it to stored it in a `terraform.tfvars` file at root level, **NOT** coded in the provider block:

  ```terraform
  # GOOD: No subscription_id in provider (uses ARM_SUBSCRIPTION_ID env var)
  provider "azurerm" {
    features {}
  }

  # BAD: Hardcoded subscription_id
  provider "azurerm" {
    subscription_id = "12345678-1234-1234-1234-123456789012"  # NEVER DO THIS
    features {}
  }
  ```

- **Environment testing**: Test configurations in non-production environments first
- **Plan review**: Generate and review `terraform plan` output for correctness before applying changes

## Idempotency

- Write configurations that can be applied repeatedly with the same outcome
- **Avoid non-idempotent actions**:
  - Scripts that run on every apply
  - Resources that might conflict if created twice
- **Test by doing multiple `terraform apply` runs** and ensure the second run results in zero changes
- Use resource lifecycle settings or conditional expressions to handle drift or external changes gracefully

## Azure-Specific Best Practices

### Resource Naming and Tagging

- **Follow Azure naming conventions**: Use recommended abbreviations and patterns (see **Naming Conventions** section)
- **Implement consistent tagging**: See **Tagging Strategy** section for tag structure and lifecycle management

### Resource Group Strategy

- **Use existing resource groups when specified**: Query for existing resource groups before creating new ones
- **Create new resource groups only when necessary**: Always confirm with the user
- **Use descriptive names**: Indicate purpose and environment (e.g., `rg-fundraising-dev-abc123`)

### Networking Considerations

- **Validate existing VNet/SubNet IDs** before creating new network resources:
  - Is this solution being deployed into an existing hub & spoke landing zone?
  - Are there existing VNets that should be reused?
  - What are the subnet requirements and CIDR ranges?
- **Use consistent region naming** and variables for multi-region deployments
- **Use Network Security Groups (NSGs) and Application Security Groups (ASGs) appropriately** for network segmentation and security
- **Implement private endpoints** for PaaS services when required
- **Use resource firewall restrictions** to restrict public access; comment exceptions where public endpoints are required
- **Plan for network peering** if multiple VNets are required

### Security and Compliance

- **Use Managed Identities** instead of service principals wherever possible (see **Identity Management** section)
- **Implement Key Vault** with appropriate RBAC for secrets management (see **Secrets Management** section)
- **Enable diagnostic settings** for audit trails on all applicable resources
- **Follow principle of least privilege** for all IAM roles and permissions
- **Enable encryption** at rest and in transit for all applicable resources

### Cost Management

- **Use environment-appropriate sizing**: Dev vs Prod (e.g., B1 for dev, P1v2 for prod)
- **Implement auto-shutdown** for dev/test resources when applicable
- **Use Azure Cost Management tags** for cost tracking and allocation

### State Management

- **Use remote backend**: Azure Storage Account with state locking
- **Implement state locking**: Prevent concurrent modifications
- **Use workspace or environment-specific state files**: Isolate environments

## Reference Material

Load these files only when the task needs them:

| File                                                                     | Load when                                                                                     |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| [references/app-configuration.md](references/app-configuration.md)       | Wiring multi-service settings into Azure App Configuration or organizing `settings_*.tf` files |
| [references/azapi-provider.md](references/azapi-provider.md)             | A resource type or property is not supported by `azurerm` and `azapi` is needed               |
| [references/file-based-seeding.md](references/file-based-seeding.md)     | Populating Table Storage, Blob Storage, or Cosmos DB with data from local files               |
| [references/validation-patterns.md](references/validation-patterns.md)   | Writing `validation` blocks for input variables                                               |

## References

- [Abbreviation recommendations for Azure resources](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)
- [Azure Naming Conventions](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Azure REST API Specifications](https://learn.microsoft.com/en-us/rest/api/azure/)
- [Terraform Best Practices](https://learn.hashicorp.com/collections/terraform/azure-get-started)
