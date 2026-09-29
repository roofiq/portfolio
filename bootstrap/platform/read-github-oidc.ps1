# Read-only Terraform external data source; stdout must contain a JSON string map.
$ErrorActionPreference = "Stop"
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "Install GitHub CLI and run gh auth login before planning platform Terraform."
}
$response = gh api repos/roofiq/portfolio/actions/oidc/customization/sub
if ($LASTEXITCODE -ne 0) { throw "Cannot read the GitHub repository OIDC settings." }
$settings = $response | ConvertFrom-Json
if ($settings.use_default -ne $true -or [string]::IsNullOrWhiteSpace($settings.sub_claim_prefix)) {
    throw "Expected the default GitHub OIDC subject with a reported prefix; review custom OIDC settings."
}
@{ prefix = $settings.sub_claim_prefix } | ConvertTo-Json -Compress
