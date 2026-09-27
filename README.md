# Squad through APIM to Foundry

This repository deploys a two-region Microsoft Foundry inference gateway for a Squad and GitHub Copilot CLI terminal-game demonstration. The architecture and acceptance criteria are in the [ADR](adr/adr-squad-copilot-apim-foundry.md).

## Current status

The Azure subscription `5089bc84-b80e-4705-9ab8-9b18198bb7b9` has a dedicated Terraform state account and a deployed gateway at `https://apim-squad-foundry-5089.azure-api.net/openai/v1`. Matching `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`, and `gpt-5.4` deployments run in France Central and Switzerland North using Global Standard. APIM uses its managed identity for backend inference and prioritizes France Central. The API currently exposes OpenAI Chat Completions only.

Authenticated inference, an APIM-generated token-limit `429`, and secondary-region failover after controlled primary `5xx` errors were observed live. The failover test restored the original backend URL and circuit breaker; a subsequent Terraform plan showed no changes. The Squad specialist roster, terminal game, Copilot BYOK integration, and per-agent attribution have **not** been verified or completed.

The token limit and metric dimension identify an authenticated APIM subscription, not an individual Squad agent. Do not interpret these measurements as per-agent costs until agent-to-subscription identity propagation has been demonstrated.

## Before provisioning

Install `azd`, Azure CLI, Terraform, GitHub Copilot CLI, Squad, and the .NET SDK. Sign in to the intended Azure subscription and select an `azd` environment. Configure the environment values required by [preflight.ps1](scripts/preflight.ps1): the subscription ID and remote Terraform state storage. Service names, regions, Foundry model deployments, and APIM settings now ship with infra defaults and only need overriding when you want non-default values. The remote state storage must already exist. Obtain cost approval for the APIM tier, Foundry deployments, and telemetry retention before provisioning.

Run the read-only checks from the repository root:

```powershell
./scripts/preflight.ps1
terraform -chdir=infra/resources init -backend=false -input=false
terraform -chdir=infra/resources validate
```

Preflight checks that the CLI account matches the configured subscription, and that any overridden regions or Foundry account names remain distinct.

Provision only after the target subscription, remote state, cost, and model compatibility are confirmed. This repository does not deploy resources automatically as part of preflight. The state storage account lives outside the workload Terraform configuration and remains after the workload is destroyed.

## Live tests

Retrieve the `demo-inference` and `demo-failover` API-scoped subscription keys from API Management in the Azure portal. Do not use the built-in all-access subscription for the tests. Each script securely prompts for its key; neither writes the key to the repository. Run the rate-limit test with `demo-inference`:

```powershell
./scripts/test-rate-limit.ps1 -BaseUrl 'https://apim-squad-foundry-5089.azure-api.net/openai/v1'
```

This sends a bounded synthetic prompt until APIM returns `429`. The gateway's diagnostic headers expose consumed and remaining tokens. A `429` caused by the gateway's token policy is not a backend failure.

Run the fault test only when no other workload uses the demo gateway. Supply the `demo-failover` subscription key when prompted:

```powershell
./scripts/test-failover.ps1 -SubscriptionId '5089bc84-b80e-4705-9ab8-9b18198bb7b9' -ResourceGroup 'rg-squad-foundry-demo-5089' -ServiceName 'apim-squad-foundry-5089' -GatewayUrl 'https://apim-squad-foundry-5089.azure-api.net' -ExpectedPrimaryUrl 'https://aisquadfoundryfc5089.cognitiveservices.azure.com/openai/v1'
```

The fault endpoint is hosted in this APIM instance and sends no Foundry credential to a third party. The script validates the primary region, temporarily redirects the primary backend to controlled `503` responses, requires a `200` response labeled `Switzerland North`, and restores the original URL and circuit breaker in `finally`. APIM can keep the circuit open for up to two minutes after restoration. Verify `terraform plan` reports no changes afterward.

## Telemetry after provisioning

In the Azure portal, open the Application Insights instance, then select **Usage and estimated costs** > **Custom metrics (Preview)** > **With dimensions** > **OK**. APIM's diagnostic enables metrics, but this separate opt-in is required to retain the subscription and backend dimensions. Review the [custom metrics limits and pricing](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights#emit-custom-metrics) before enabling dimensions. Keep subscription cardinality bounded.

Gateway policy acceptance, Chat Completions inference, and controlled `5xx` failover were tested. The telemetry dimensions, Workbook, Copilot CLI BYOK contract, and Squad agent identity propagation still need end-to-end validation. Backend `5xx` responses count toward the circuit breaker; gateway token-limit `429` responses do not.
