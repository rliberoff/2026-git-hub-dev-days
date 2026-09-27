$ErrorActionPreference = 'Stop'

foreach ($name in @('azd', 'az', 'terraform', 'copilot', 'squad', 'dotnet')) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "$name is required but was not found on PATH."
    }
}

$environmentJson = azd env get-values --output json 2>&1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($environmentJson | Out-String))) {
    throw "Select an azd environment and set its Terraform inputs before provisioning: $environmentJson"
}

$environment = $environmentJson | ConvertFrom-Json
$required = @(
    'AZURE_ENV_NAME',
    'RS_STORAGE_ACCOUNT',
    'RS_CONTAINER_NAME',
    'RS_RESOURCE_GROUP',
    'TF_VAR_subscription_id',
    'TF_VAR_tenant_id',
    'TF_VAR_resource_group_name',
    'TF_VAR_primary_region',
    'TF_VAR_secondary_region',
    'TF_VAR_foundry_primary_name',
    'TF_VAR_foundry_secondary_name',
    'TF_VAR_model_deployments',
    'TF_VAR_deployment_sku',
    'TF_VAR_apim_name',
    'TF_VAR_apim_publisher_name',
    'TF_VAR_apim_publisher_email',
    'TF_VAR_apim_sku_name',
    'TF_VAR_apim_tokens_per_minute',
    'TF_VAR_log_analytics_name',
    'TF_VAR_application_insights_name'
)
$missing = @($required | Where-Object {
    -not $environment.PSObject.Properties[$_] -or
    [string]::IsNullOrWhiteSpace([string]$environment.$_)
})
if ($missing.Count -gt 0) {
    throw "Set the following values in the active azd environment: $($missing -join ', ')"
}

if ($environment.TF_VAR_primary_region -eq $environment.TF_VAR_secondary_region -or
    $environment.TF_VAR_foundry_primary_name -eq $environment.TF_VAR_foundry_secondary_name) {
    throw 'Select distinct regions and Foundry accounts.'
}

$accountJson = az account show --output json 2>&1
if ($LASTEXITCODE -ne 0) {
    throw 'Sign in to Azure CLI before provisioning with azd.'
}

$account = $accountJson | ConvertFrom-Json
if ($account.id -ne $environment.TF_VAR_subscription_id -or
    $account.tenantId -ne $environment.TF_VAR_tenant_id) {
    throw 'Azure CLI subscription or tenant differs from the active azd environment.'
}

$models = $environment.TF_VAR_model_deployments | ConvertFrom-Json -AsHashtable
if ($models.Count -eq 0) {
    throw 'TF_VAR_model_deployments must contain at least one model.'
}

$accessToken = az account get-access-token --subscription $account.id --resource https://management.azure.com --query accessToken --output tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accessToken)) {
    throw 'Cannot acquire an Azure Resource Manager access token for the selected subscription.'
}
try {
    foreach ($region in @($environment.TF_VAR_primary_region, $environment.TF_VAR_secondary_region)) {
        $catalogJson = az cognitiveservices model list --location $region --subscription $account.id --output json
        if ($LASTEXITCODE -ne 0) {
            throw "Cannot read the model catalog in $region."
        }
        $catalog = $catalogJson | ConvertFrom-Json

        $usageJson = az cognitiveservices usage list --location $region --subscription $account.id --output json
        if ($LASTEXITCODE -ne 0) {
            throw "Cannot read model quota in $region. Verify Cognitive Services Usages Reader permission at subscription scope."
        }
        $usage = $usageJson | ConvertFrom-Json

        foreach ($name in $models.Keys) {
            $model = $models[$name]
            $capacity = 0
            if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($model.version) -or
                -not [int]::TryParse([string]$model.capacity, [ref]$capacity) -or $capacity -le 0) {
                throw "Invalid model name, version or capacity for $name."
            }

            $supported = @($catalog | Where-Object {
                $_.model.name -eq $name -and $_.model.version -eq $model.version -and
                $_.model.skus.name -contains $environment.TF_VAR_deployment_sku
            })
            if ($supported.Count -eq 0) {
                throw "Model $name $($model.version) does not support $($environment.TF_VAR_deployment_sku) in $region."
            }

            $quotaName = "OpenAI.$($environment.TF_VAR_deployment_sku).$name"
            $quota = @($usage | Where-Object { $_.name.value -eq $quotaName })
            if ($quota.Count -ne 1 -or ($quota[0].limit - $quota[0].currentValue) -lt $capacity) {
                throw "Insufficient subscription quota for $quotaName in $region (need $capacity units)."
            }

            $modelName = [uri]::EscapeDataString($name)
            $modelVersion = [uri]::EscapeDataString($model.version)
            $url = "https://management.azure.com/subscriptions/$($account.id)/providers/Microsoft.CognitiveServices/modelCapacities?api-version=2024-10-01&modelFormat=OpenAI&modelName=$modelName&modelVersion=$modelVersion"
            try {
                $available = (Invoke-RestMethod -Method Get -Uri $url -Headers @{ Authorization = "Bearer $accessToken" }).value
            } catch {
                throw "Cannot read deployable capacity for $name $($model.version)."
            }
            if (-not @($available | Where-Object {
                $_.location -eq $region -and $_.properties.skuName -eq $environment.TF_VAR_deployment_sku -and
                $_.properties.availableCapacity -ge $capacity
            }).Count) {
                throw "Insufficient deployable capacity for $name $($model.version) in $region (need $capacity units)."
            }
        }
    }
} finally {
    $accessToken = $null
}

Write-Output "Preflight passed for azd environment $($environment.AZURE_ENV_NAME)."