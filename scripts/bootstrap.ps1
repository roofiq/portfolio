<#
.SYNOPSIS
Creates storage for Terraform state and grants your Azure user access.

.DESCRIPTION
Run from a clone of this repository after az login. Requires Azure CLI and
permission to create storage resources and assign roles (such as subscription
Owner). This script creates only rg-portfolio-tfstate, a Standard_LRS storage
account, the private tfstate container, and your user's Storage Blob Data
Contributor assignment on that container. Storage incurs normal Azure charges.
It also registers Microsoft.Storage if the subscription has not enabled it yet.
A storage key is used only to create the container; Terraform uses Entra auth.

If Azure reports AADSTS50076, complete MFA through an interactive sign-in:
    az login --scope https://management.core.windows.net//.default
Then rerun this script with the same subscription ID.

NEXT: LOCAL TERRAFORM
Install Terraform, PowerShell 7 (pwsh), and GitHub CLI; run gh auth login.
Your Azure user needs permission to create/manage Entra applications, portfolio
resources, and role assignments. Your GitHub user needs repository admin access.
The script saves subscription, state account, and region inputs in the ignored
bootstrap/platform/bootstrap.auto.tfvars.json file. From the repository root:
    $env:GITHUB_TOKEN = gh auth token
    terraform -chdir=bootstrap/platform init -lockfile=readonly -backend-config="storage_account_name=<printed-state-account-name>"
    terraform -chdir=bootstrap/platform plan -out=platform.tfplan
    terraform -chdir=bootstrap/platform apply platform.tfplan
    Remove-Item Env:GITHUB_TOKEN

Local Terraform manages the portfolio resource group, Microsoft.Web registration,
Entra application, service principal, GitHub OIDC credential, Azure roles, and
GitHub production environment with its main-only rule and Azure variables.
Its OIDC lookup reads GitHub through gh during plan; numeric IDs are not hardcoded.
The resource group defaults to Poland Central; Static Web Apps uses West Europe
because its available hosting regions differ from resource group regions.

The local configuration keeps the existing portfolio-github.tfstate backend key
to preserve state from the former bootstrap/github directory. If you applied
that configuration before, initialize the new directory against the same account.
If an earlier script created the app, service principal, credential, resource
group, or role assignments, import those existing resources before applying;
do not create duplicate identities. Review the plan for unexpected replacements.

NEXT: GITHUB ACTIONS
Once local Terraform has applied, push to main or manually run Infrastructure.
CI validates both configurations but applies only infra/. It uses the GitHub
identity and portfolio-prod.tfstate. Azure RBAC can take a few minutes to
propagate; retry authorization failures after propagation.

LOCAL APPLICATION TERRAFORM
    $env:ARM_SUBSCRIPTION_ID = "<subscription-guid>"
    terraform -chdir=infra init -lockfile=readonly -backend-config="storage_account_name=<printed-state-account-name>"
    terraform -chdir=infra plan

.PARAMETER SubscriptionId
Azure subscription GUID used for state storage and platform Terraform.
.PARAMETER Location
Region for state storage and the portfolio resource group; defaults to polandcentral.
.EXAMPLE
.\scripts\bootstrap.ps1 -SubscriptionId "<subscription-guid>"
.EXAMPLE
Get-Help .\scripts\bootstrap.ps1 -Full
#>
param(
    [Parameter(Mandatory = $true)]
    [guid] $SubscriptionId,
    [string] $Location = "polandcentral"
)

$ErrorActionPreference = "Stop"
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Install Azure CLI and sign in with az login."
}
$platformDirectory = Join-Path $PSScriptRoot "../bootstrap/platform"
if (-not (Test-Path -LiteralPath $platformDirectory)) {
    throw "Run this script from a full repository clone so platform inputs can be saved."
}
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { throw "Cannot select the Azure subscription." }
# Check the management token before attempting any resource writes. Suppress
# token output so credentials never appear in the console or pipeline logs.
az account get-access-token --resource https://management.core.windows.net/ --output none
if ($LASTEXITCODE -ne 0) {
    throw "Cannot authenticate to Azure Resource Manager. Run 'az login --scope https://management.core.windows.net//.default', complete MFA if prompted, then rerun this script."
}
$userId = az ad signed-in-user show --query id -o tsv
if ($LASTEXITCODE -ne 0 -or -not $userId) { throw "Sign in to Azure CLI with your user account." }

$stateAccount = "stportfoliotf$($SubscriptionId.ToString('N').Substring(0, 10))"
$stateGroup = "rg-portfolio-tfstate"
$storageRegistration = az provider show --namespace Microsoft.Storage --subscription $SubscriptionId --query registrationState -o tsv
if ($LASTEXITCODE -ne 0 -or -not $storageRegistration) {
    throw "Cannot read Microsoft.Storage registration for subscription $SubscriptionId. Check the Azure CLI error above and your subscription access."
}
if ($storageRegistration -ne "Registered") {
    Write-Output "Registering Microsoft.Storage for subscription $SubscriptionId..."
    az provider register --namespace Microsoft.Storage --subscription $SubscriptionId --wait --output none
    if ($LASTEXITCODE -ne 0) { throw "Cannot register Microsoft.Storage. Your account needs subscription-level resource provider registration permission." }
}
az group create --name $stateGroup --location $Location --output none
if ($LASTEXITCODE -ne 0) { throw "Cannot create the state resource group. Check the Azure CLI error above. For AADSTS50076, run 'az login --scope https://management.core.windows.net//.default', complete MFA, and retry." }
az storage account show --resource-group $stateGroup --name $stateAccount --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    az storage account create --resource-group $stateGroup --name $stateAccount --location $Location --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 --allow-blob-public-access false --output none
    if ($LASTEXITCODE -ne 0) { throw "Cannot create the state storage account." }
}
$stateKey = az storage account keys list --resource-group $stateGroup --account-name $stateAccount --query "[0].value" -o tsv
if ($LASTEXITCODE -ne 0 -or -not $stateKey) { throw "Cannot access the state account to create its container." }
try {
    az storage container create --name tfstate --account-name $stateAccount --account-key $stateKey --output none
    if ($LASTEXITCODE -ne 0) { throw "Cannot create the state container." }
} finally {
    Remove-Variable stateKey
}
$scope = "/subscriptions/$SubscriptionId/resourceGroups/$stateGroup/providers/Microsoft.Storage/storageAccounts/$stateAccount/blobServices/default/containers/tfstate"
$existing = az role assignment list --assignee $userId --scope $scope --query "[?roleDefinitionName=='Storage Blob Data Contributor'].id" -o tsv
if ($LASTEXITCODE -ne 0) { throw "Cannot check your state access." }
if (-not $existing) {
    az role assignment create --assignee-object-id $userId --assignee-principal-type User --role "Storage Blob Data Contributor" --scope $scope --output none
    if ($LASTEXITCODE -ne 0) { throw "Cannot grant your user access to Terraform state." }
}
$inputs = @{
    subscription_id = $SubscriptionId.ToString()
    state_storage_account_name = $stateAccount
    location = $Location
} | ConvertTo-Json
[System.IO.File]::WriteAllText((Join-Path $platformDirectory "bootstrap.auto.tfvars.json"), $inputs)
Write-Output "State storage ready: $stateAccount / tfstate"
Write-Output "Platform inputs saved. Follow Get-Help .\scripts\bootstrap.ps1 -Full to apply local Terraform."
