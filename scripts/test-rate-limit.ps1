param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$BaseUrl,

    [ValidateRange(2, 30)]
    [int]$MaxAttempts = 12,

    [ValidateRange(1, 1500)]
    [int]$PromptWords = 650,

    [string]$Model = 'gpt-5.6-sol',

    [securestring]$SubscriptionKey
)

$ErrorActionPreference = 'Stop'
if (-not $SubscriptionKey) {
    $SubscriptionKey = Read-Host 'APIM demo-ratelimit subscription key' -AsSecureString
}
$keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SubscriptionKey)

try {
    $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
    $headers = @{ 'Ocp-Apim-Subscription-Key' = $key }
    $body = @{
        model             = $Model
        input             = "Acknowledge this capacity check: $(('capacity ' * $PromptWords).TrimEnd())"
        max_output_tokens = 30
    } | ConvertTo-Json -Depth 5
    $endpoint = "$($BaseUrl.TrimEnd('/'))/responses"
    $succeeded = $false

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $response = Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -ContentType 'application/json' -Body $body -SkipHttpErrorCheck
        if ($response.StatusCode -eq 429 -and $succeeded) {
            Write-Output "APIM returned 429 after $($attempt - 1) successful requests."
            return
        }
        if ($response.StatusCode -ne 200) {
            throw "Request $attempt returned HTTP $($response.StatusCode); expected 200 followed by a gateway 429."
        }
        $succeeded = $true
    }

    throw "No 429 observed in $MaxAttempts attempts. Check that the key belongs to the demo-ratelimit subscription and retry after the counter resets."
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
    $headers = $null
    $key = $null
}