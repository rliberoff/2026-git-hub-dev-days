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
    'AZURE_SUBSCRIPTION_ID'
)
$missing = @($required | Where-Object {
    -not $environment.PSObject.Properties[$_] -or
    [string]::IsNullOrWhiteSpace([string]$environment.$_)
})
if ($missing.Count -gt 0) {
    throw "Set the following values in the active azd environment: $($missing -join ', ')"
}

# The remaining Terraform variables have infra defaults; only compare them when the azd environment overrides them.
if (-not [string]::IsNullOrWhiteSpace([string]$environment.TF_VAR_primary_region) -and
    -not [string]::IsNullOrWhiteSpace([string]$environment.TF_VAR_secondary_region) -and
    $environment.TF_VAR_primary_region -eq $environment.TF_VAR_secondary_region) {
    throw 'Select distinct primary and secondary regions.'
}
if (-not [string]::IsNullOrWhiteSpace([string]$environment.TF_VAR_foundry_primary_name) -and
    -not [string]::IsNullOrWhiteSpace([string]$environment.TF_VAR_foundry_secondary_name) -and
    $environment.TF_VAR_foundry_primary_name -eq $environment.TF_VAR_foundry_secondary_name) {
    throw 'Select distinct primary and secondary Foundry account names.'
}

$accountJson = az account show --output json 2>&1
if ($LASTEXITCODE -ne 0) {
    throw 'Sign in to Azure CLI before provisioning with azd.'
}

$account = $accountJson | ConvertFrom-Json
if ($account.id -ne $environment.AZURE_SUBSCRIPTION_ID) {
    throw 'Azure CLI subscription differs from the active azd environment.'
}

Write-Output "Preflight passed for azd environment $($environment.AZURE_ENV_NAME)."