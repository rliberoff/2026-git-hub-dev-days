resource "random_id" "random" {
  byte_length = 8
}

locals {
  suffix                       = lower(trimspace(var.use_random_suffix ? substr(lower(random_id.random.hex), 1, 5) : var.suffix))
  name_suffix                  = local.suffix != null ? "-${local.suffix}" : ""
  name_resource_group          = "${var.resource_group_name}${local.name_suffix}"
  name_foundry_primary         = "${var.foundry_primary_name}${local.name_suffix}"
  name_foundry_secondary       = "${var.foundry_secondary_name}${local.name_suffix}"
  name_log_analytics_workspace = "${var.log_analytics_name}${local.name_suffix}"
  name_application_insights    = "${var.application_insights_name}${local.name_suffix}"
  name_apim                    = "${var.apim_name}${local.name_suffix}"

  tags = merge(var.tags, {
    createdAt = "${formatdate("YYYY-MM-DD hh:mm:ss", timestamp())} UTC"
    suffix    = local.suffix
  })
}

module "resource_group" {
  source = "./modules/resource-group"

  name     = local.name_resource_group
  location = var.primary_region
  tags     = local.tags
}

module "foundry_primary" {
  source = "./modules/foundry-model"

  name                = local.name_foundry_primary
  location            = var.primary_region
  resource_group_name = module.resource_group.name
  model_deployments   = var.foundry_model_deployments
  tags                = local.tags
}

module "foundry_secondary" {
  source = "./modules/foundry-model"

  name                = local.name_foundry_secondary
  location            = var.secondary_region
  resource_group_name = module.resource_group.name
  model_deployments   = var.foundry_model_deployments
  tags                = local.tags
}

module "log_analytics" {
  source = "./modules/log-analytics"

  name                = local.name_log_analytics_workspace
  location            = var.primary_region
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "application_insights" {
  source = "./modules/application-insights"

  name                = local.name_application_insights
  location            = var.primary_region
  resource_group_name = module.resource_group.name
  workspace_id        = module.log_analytics.id
  tags                = local.tags
}

module "api_management" {
  source = "./modules/api-management"

  name                = local.name_apim
  location            = var.primary_region
  resource_group_name = module.resource_group.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name
  tokens_per_minute   = var.apim_tokens_per_minute
  foundry_account_ids = {
    primary   = module.foundry_primary.id
    secondary = module.foundry_secondary.id
  }
  foundry_endpoints = {
    primary   = module.foundry_primary.endpoint
    secondary = module.foundry_secondary.endpoint
  }
  application_insights_id                = module.application_insights.id
  application_insights_connection_string = module.application_insights.connection_string
  tags                                   = local.tags
}
