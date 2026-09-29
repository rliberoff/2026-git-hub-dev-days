resource "azurerm_api_management" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_role_assignment" "foundry_inference" {
  for_each = var.foundry_account_ids

  scope                = each.value
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_api_management.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_api_management_backend" "foundry" {
  for_each = var.foundry_endpoints

  name                = "foundry-${each.key}"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  protocol            = "http"
  url                 = "${trimsuffix(each.value, "/")}/openai/v1"

  circuit_breaker_rule {
    name                       = "regional-unavailable"
    trip_duration              = "PT2M"
    accept_retry_after_enabled = false

    failure_condition {
      interval_duration = "PT1M"
      count             = 3

      status_code_range {
        min = 500
        max = 599
      }
    }
  }
}

# AzureRM does not expose backend pools; use the stable APIM ARM API for the pool only.
resource "azapi_resource" "foundry_pool" {
  type      = "Microsoft.ApiManagement/service/backends@2024-05-01"
  name      = "foundry-failover"
  parent_id = azurerm_api_management.this.id

  body = {
    properties = {
      type = "Pool"
      pool = {
        services = [
          { id = azurerm_api_management_backend.foundry["primary"].id, priority = 1, weight = 1 },
          { id = azurerm_api_management_backend.foundry["secondary"].id, priority = 2, weight = 1 },
        ]
      }
    }
  }
}

resource "azurerm_api_management_api" "openai" {
  name                  = "openai-v1"
  api_management_name   = azurerm_api_management.this.name
  resource_group_name   = var.resource_group_name
  revision              = "1"
  display_name          = "OpenAI v1 inference"
  path                  = "openai/v1"
  protocols             = ["https"]
  subscription_required = true
}

resource "azurerm_api_management_subscription" "demo" {
  subscription_id     = "demo-inference"
  display_name        = "Squad demo inference"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  api_id              = split(";", azurerm_api_management_api.openai.id)[0]
  state               = "active"
  allow_tracing       = true
}

resource "azurerm_api_management_subscription" "failover" {
  subscription_id     = "demo-failover"
  display_name        = "Squad demo failover"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  api_id              = split(";", azurerm_api_management_api.openai.id)[0]
  state               = "active"
  allow_tracing       = true
}

# Deliberately throttled subscription used only to provoke a gateway 429 on demand.
resource "azurerm_api_management_subscription" "ratelimit" {
  subscription_id     = "demo-ratelimit"
  display_name        = "Squad demo rate limit"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  api_id              = split(";", azurerm_api_management_api.openai.id)[0]
  state               = "active"
  allow_tracing       = true
}

resource "azurerm_api_management_api" "demo_fault" {
  name                  = "demo-fault"
  api_management_name   = azurerm_api_management.this.name
  resource_group_name   = var.resource_group_name
  revision              = "1"
  display_name          = "Demo backend failure"
  path                  = "demo-fault"
  protocols             = ["https"]
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "demo_fault_responses" {
  operation_id        = "responses"
  api_name            = azurerm_api_management_api.demo_fault.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  display_name        = "Simulate primary 503 for responses"
  method              = "POST"
  url_template        = "/responses"
}

resource "azurerm_api_management_api_policy" "demo_fault" {
  api_name            = azurerm_api_management_api.demo_fault.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name

  xml_content = <<-XML
    <policies>
      <inbound>
        <set-header name="Authorization" exists-action="delete" />
        <return-response>
          <set-status code="503" reason="Demo backend unavailable" />
          <set-header name="x-demo-fault" exists-action="override"><value>primary</value></set-header>
        </return-response>
      </inbound>
      <backend><base /></backend>
      <outbound><base /></outbound>
      <on-error><base /></on-error>
    </policies>
  XML
}

resource "azurerm_api_management_api_operation" "responses" {
  operation_id        = "responses"
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  display_name        = "Create response"
  method              = "POST"
  url_template        = "/responses"
}

resource "azurerm_api_management_api_policy" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name

  xml_content = <<-XML
    <policies>
      <inbound>
        <base />
        <trace source="CopilotGateway" severity="verbose">
          <message>@(string.Concat("inbound request=", context.RequestId, "; subscription=", context.Subscription?.Id ?? "none", "; api=", context.Api?.Name ?? "none", "; operation=", context.Operation?.Name ?? "none"))</message>
        </trace>
        <choose>
          <when condition='@(context.Subscription?.Id != "${azurerm_api_management_subscription.demo.subscription_id}")'>
            <choose>
              <when condition='@(context.Subscription?.Id == "${azurerm_api_management_subscription.ratelimit.subscription_id}")'>
                <!-- Custom retry header replaces the standard `Retry-After` so clients fall back to their own short backoff. -->
                <llm-token-limit counter-key="@(context.Subscription.Id)" tokens-per-minute="${var.ratelimit_tokens_per_minute}" estimate-prompt-tokens="true" retry-after-header-name="x-demo-retry-after" remaining-tokens-header-name="x-demo-remaining-tokens" tokens-consumed-header-name="x-demo-consumed-tokens" />
              </when>
              <otherwise>
                <llm-token-limit counter-key="@(context.Subscription.Id)" tokens-per-minute="${var.tokens_per_minute}" token-quota="${var.token_quota}" token-quota-period="${var.token_quota_period}" estimate-prompt-tokens="false" remaining-tokens-header-name="x-demo-remaining-tokens" remaining-quota-tokens-header-name="x-demo-remaining-quota-tokens" tokens-consumed-header-name="x-demo-consumed-tokens" />
              </otherwise>
            </choose>
          </when>
          <otherwise>
            <trace source="CopilotGateway" severity="verbose">
              <message>@(string.Concat("token policy=unlimited-apim; subscription=", context.Subscription?.Id ?? "none"))</message>
            </trace>
          </otherwise>
        </choose>
        <llm-emit-token-metric namespace="CopilotGateway">
          <dimension name="Subscription ID" />
          <dimension name="Backend ID" />
        </llm-emit-token-metric>
        <set-header name="Ocp-Apim-Subscription-Key" exists-action="delete" />
        <set-header name="api-key" exists-action="delete" />
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" ignore-error="false" />
        <set-backend-service backend-id="${azapi_resource.foundry_pool.name}" />
        <trace source="CopilotGateway" severity="verbose">
          <message>@(string.Concat("backend selected=", "${azapi_resource.foundry_pool.name}", "; request=", context.RequestId))</message>
        </trace>
      </inbound>
      <backend><base /></backend>
      <outbound><base /></outbound>
      <on-error><base /></on-error>
    </policies>
  XML
}

resource "azurerm_role_assignment" "metrics_publisher" {
  scope                = var.application_insights_id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_api_management.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_api_management_logger" "application_insights" {
  name                = "application-insights"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  resource_id         = var.application_insights_id

  application_insights {
    connection_string  = var.application_insights_connection_string
    identity_client_id = "SystemAssigned"
  }

  depends_on = [azurerm_role_assignment.metrics_publisher]
}

# AzureRM does not expose the metrics flag required for LLM token metric policies.
resource "azapi_resource" "openai_diagnostic" {
  type      = "Microsoft.ApiManagement/service/apis/diagnostics@2024-05-01"
  name      = "applicationinsights"
  parent_id = azurerm_api_management_api.openai.id

  body = {
    properties = {
      loggerId                = azurerm_api_management_logger.application_insights.id
      metrics                 = true
      alwaysLog               = "allErrors"
      verbosity               = "verbose"
      logClientIp             = false
      httpCorrelationProtocol = "W3C"
      sampling = {
        samplingType = "fixed"
        percentage   = 100
      }
    }
  }
}
