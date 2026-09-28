param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$ServiceName,

    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$GatewayUrl,

    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$ExpectedPrimaryUrl,

    [Parameter(Mandatory)]
    [string]$PrimaryRegion,

    [Parameter(Mandatory)]
    [string]$SecondaryRegion,

    [ValidateRange(4, 20)]
    [int]$MaxAttempts = 10,

    [ValidateRange(30, 600)]
    [int]$PropagationTimeoutSeconds = 180,

    [securestring]$SubscriptionKey
)

$ErrorActionPreference = 'Stop'

# APIM reports x-ms-region as a display name ('France Central'); Azure region inputs are compact ('francecentral').
function Get-NormalizedRegion {
    param([object]$Value)
    return (([string]::Join('', @($Value))) -replace '\s', '').ToLowerInvariant()
}

$expectedPrimaryRegion = Get-NormalizedRegion $PrimaryRegion
$expectedSecondaryRegion = Get-NormalizedRegion $SecondaryRegion
$gateway = $GatewayUrl.TrimEnd('/')
$faultUrl = "$gateway/demo-fault"
$backendId = 'foundry-primary'
$armToken = az account get-access-token --subscription $SubscriptionId --resource https://management.azure.com --query accessToken --output tsv
if ($LASTEXITCODE -ne 0 -or -not $armToken) {
    throw 'Cannot acquire an Azure Resource Manager token.'
}
$backendUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ServiceName/backends/$backendId`?api-version=2024-05-01"
$backend = Invoke-RestMethod -Method Get -Uri $backendUrl -Headers @{ Authorization = "Bearer $armToken" }
$originalUrl = $backend.properties.url
$originalBreaker = $backend.properties.circuitBreaker
if ($originalUrl -ne $ExpectedPrimaryUrl.TrimEnd('/') -or
    $originalBreaker.rules[0].failureCondition.count -ne 3) {
    throw 'The primary backend URL differs from the expected Foundry endpoint; no changes were made.'
}

$fault = Invoke-WebRequest -Uri "$faultUrl/chat/completions" -Method Post -ContentType 'application/json' -Body '{}' -SkipHttpErrorCheck
if ($fault.StatusCode -ne 503 -or $fault.Headers['x-demo-fault'] -ne 'primary') {
    throw 'The gateway-local 503 endpoint is unavailable; no changes were made.'
}

if (-not $SubscriptionKey) {
    $SubscriptionKey = Read-Host 'APIM failover subscription key' -AsSecureString
}
$keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SubscriptionKey)
$changed = $false

try {
    $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
    $headers = @{ 'Ocp-Apim-Subscription-Key' = $key }
    $body = @{ model = 'gpt-5.6-sol'; messages = @(@{ role = 'user'; content = 'Reply OK.' }); max_completion_tokens = 30 } | ConvertTo-Json -Depth 5
    $endpoint = "$gateway/openai/v1/chat/completions"
    $baseline = Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -ContentType 'application/json' -Body $body -SkipHttpErrorCheck
    if ($baseline.StatusCode -ne 200 -or (Get-NormalizedRegion $baseline.Headers['x-ms-region']) -ne $expectedPrimaryRegion) {
        throw "Primary baseline was not $PrimaryRegion (HTTP $($baseline.StatusCode)); no changes were made."
    }

    $changed = $true
    $faultBody = @{ properties = @{ url = $faultUrl; protocol = 'http'; circuitBreaker = $originalBreaker } } | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Method Patch -Uri $backendUrl -Headers @{ Authorization = "Bearer $armToken"; 'If-Match' = '*' } -ContentType 'application/json' -Body $faultBody | Out-Null
    $backend = Invoke-RestMethod -Method Get -Uri $backendUrl -Headers @{ Authorization = "Bearer $armToken" }
    if ($backend.properties.url -ne $faultUrl -or $backend.properties.circuitBreaker.rules[0].failureCondition.count -ne 3 -or
        $backend.properties.circuitBreaker.rules[0].failureCondition.statusCodeRanges[0].min -ne 500) {
        throw 'The backend URL or 5xx circuit breaker changed unexpectedly.'
    }

    $propagationDeadline = [DateTimeOffset]::UtcNow.AddSeconds($PropagationTimeoutSeconds)
    do {
        $response = Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -ContentType 'application/json' -Body $body -SkipHttpErrorCheck
        if ($response.StatusCode -eq 200 -and (Get-NormalizedRegion $response.Headers['x-ms-region']) -eq $expectedSecondaryRegion) {
            Write-Output "Failover confirmed while waiting for the backend update to reach the gateway: $SecondaryRegion answered."
            return
        }
        if ($response.StatusCode -eq 503 -and $response.Headers['x-demo-fault'] -eq 'primary') {
            Write-Output 'The simulated primary failure is active on the gateway.'
            break
        }
        if ($response.StatusCode -notin @(200, 503)) {
            throw "Backend propagation check returned unexpected HTTP $($response.StatusCode); expected primary 200, simulated 503, or secondary 200."
        }
        Start-Sleep -Seconds 2
    } while ([DateTimeOffset]::UtcNow -lt $propagationDeadline)

    if ($response.StatusCode -ne 503 -or $response.Headers['x-demo-fault'] -ne 'primary') {
        throw "The simulated backend URL did not reach the gateway within $PropagationTimeoutSeconds seconds. Last response: HTTP $($response.StatusCode), region '$($response.Headers['x-ms-region'])', fault '$($response.Headers['x-demo-fault'])'."
    }

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $response = Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -ContentType 'application/json' -Body $body -SkipHttpErrorCheck
        if ($response.StatusCode -eq 200 -and (Get-NormalizedRegion $response.Headers['x-ms-region']) -eq $expectedSecondaryRegion) {
            Write-Output "Failover confirmed on request ${attempt}: $SecondaryRegion answered after primary 5xx failures."
            return
        }
        if ($response.StatusCode -notin @(200, 503)) {
            throw "Request $attempt returned unexpected HTTP $($response.StatusCode); expected 503 or secondary 200."
        }
    }

    throw "No secondary response observed after $MaxAttempts requests; inspect APIM backend diagnostics."
} finally {
    if ($changed) {
        $restoreBody = @{ properties = @{ url = $originalUrl; protocol = 'http'; circuitBreaker = $originalBreaker } } | ConvertTo-Json -Depth 10
        try {
            Invoke-RestMethod -Method Patch -Uri $backendUrl -Headers @{ Authorization = "Bearer $armToken"; 'If-Match' = '*' } -ContentType 'application/json' -Body $restoreBody | Out-Null
            $restored = Invoke-RestMethod -Method Get -Uri $backendUrl -Headers @{ Authorization = "Bearer $armToken" }
        } catch {
            throw "PRIMARY BACKEND RESTORE FAILED. Restore $backendId to $originalUrl before further requests."
        }
        if ($restored.properties.url -ne $originalUrl -or $restored.properties.circuitBreaker.rules[0].failureCondition.count -ne 3) {
            throw "PRIMARY BACKEND RESTORE UNVERIFIED. Confirm $backendId points to $originalUrl with its 5xx breaker."
        }
        Write-Output 'Primary backend URL and 5xx circuit breaker restored. The circuit can remain open for up to two minutes.'
    }
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
    $headers = $null
    $key = $null
    $armToken = $null
}