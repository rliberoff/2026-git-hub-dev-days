# Squad through APIM to Foundry

This repository deploys a two-region Microsoft Foundry inference gateway for a Squad and GitHub Copilot CLI terminal-game demonstration. The architecture and acceptance criteria are in the [ADR](adr/adr-squad-copilot-apim-foundry.md).

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

Retrieve the `demo-inference`, `demo-failover`, and `demo-ratelimit` API-scoped subscription keys from API Management in the Azure portal. Do not use the built-in all-access subscription for the tests. Each script securely prompts for its key; neither writes the key to the repository.

`demo-inference` and `demo-failover` carry the working limits: a high token rate plus a token quota, enforced from the backend's reported usage. `demo-ratelimit` is deliberately throttled and estimates prompt tokens in advance, so it returns `429` quickly without affecting a live Copilot session.

Read the deployment-specific values from the Terraform outputs instead of hard-coding them:

```powershell
$SubscriptionId = az account show --query id --output tsv
$ResourceGroup = terraform -chdir=infra/resources output -raw resource_group_name
$ServiceName = terraform -chdir=infra/resources output -raw apim_name
$GatewayUrl = terraform -chdir=infra/resources output -raw apim_gateway_url
$CopilotBaseUrl = terraform -chdir=infra/resources output -raw copilot_base_url
$ExpectedPrimaryUrl = terraform -chdir=infra/resources output -raw apim_primary_backend_url
$PrimaryRegion = terraform -chdir=infra/resources output -raw primary_region
$SecondaryRegion = terraform -chdir=infra/resources output -raw secondary_region
```

Run the rate-limit test with `demo-ratelimit`:

```powershell
./scripts/test-rate-limit.ps1 -BaseUrl $CopilotBaseUrl
```

This sends a bounded synthetic prompt until APIM returns `429`. The gateway's diagnostic headers expose consumed and remaining tokens. A `429` caused by the gateway's token policy is not a backend failure.

Run the fault test only when no other workload uses the demo gateway. Supply the `demo-failover` subscription key when prompted:

```powershell
./scripts/test-failover.ps1 -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroup -ServiceName $ServiceName -GatewayUrl $GatewayUrl -ExpectedPrimaryUrl $ExpectedPrimaryUrl -PrimaryRegion $PrimaryRegion -SecondaryRegion $SecondaryRegion
```

The fault endpoint is hosted in this APIM instance and sends no Foundry credential to a third party. The script validates the primary region, temporarily redirects the primary backend to controlled `503` responses, requires a `200` response from the secondary region, and restores the original URL and circuit breaker in `finally`. APIM can keep the circuit open for up to two minutes after restoration. Verify `terraform plan` reports no changes afterward.

## Telemetry after provisioning

In the Azure portal, open the Application Insights instance, then select **Usage and estimated costs** > **Custom metrics (Preview)** > **With dimensions** > **OK**. APIM's diagnostic enables metrics, but this separate opt-in is required to retain the subscription and backend dimensions. Review the [custom metrics limits and pricing](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights#emit-custom-metrics) before enabling dimensions. Keep subscription cardinality bounded.

Gateway policy acceptance, Chat Completions inference, and controlled `5xx` failover were tested. The telemetry dimensions, Workbook, Copilot CLI BYOK contract, and Squad agent identity propagation still need end-to-end validation. Backend `5xx` responses count toward the circuit breaker; gateway token-limit `429` responses do not.
