# Portfolio

My personal portfolio, showcasing my projects, technical skills, and experience.

The site is planned as a static website built with Hugo and hosted on Azure
Static Web Apps, with infrastructure managed through Terraform and GitHub Actions.
Infrastructure setup is in progress; portfolio content will follow.

## Initial setup

Install PowerShell 7, Azure CLI, GitHub CLI, and Terraform. Run the commands below
from the repository root in PowerShell. Your accounts need permission to create
Azure resources, Entra applications, and role assignments, plus GitHub repository
administration access.

1. Sign in and create storage for Terraform state:

   ```powershell
   az login --scope https://management.core.windows.net//.default
   gh auth login
   .\scripts\bootstrap.ps1 -SubscriptionId "<subscription-guid>"
   ```

   Complete MFA when prompted. If Azure reports `AADSTS50076`, repeat the login
   command, complete MFA, and rerun the bootstrap with the same subscription ID.

2. Configure the Azure deployment identity and GitHub environment with local
   Terraform. Replace the storage account placeholder with the name printed above:

   ```powershell
   $env:GITHUB_TOKEN = gh auth token
   terraform -chdir=bootstrap/platform init -lockfile=readonly -backend-config="storage_account_name=<printed-state-account-name>"
   terraform -chdir=bootstrap/platform plan -out=platform.tfplan
   terraform -chdir=bootstrap/platform apply platform.tfplan
   Remove-Item Env:GITHUB_TOKEN
   ```

3. Push the infrastructure files to `main`, or run **Actions → Infrastructure →
   Run workflow** on `main` once the workflow is available on GitHub. It provisions
   the Static Web App; publishing portfolio content will be added later.

For details, existing-resource imports, and local Terraform usage, see
[scripts/bootstrap.ps1](scripts/bootstrap.ps1) or run
`Get-Help .\scripts\bootstrap.ps1 -Full`.

Local platform Terraform also protects `main`: changes require a pull request,
both validation checks, and resolved review conversations. Reviewer approval is
optional so you can merge your own PRs. Force pushes and branch deletion are
blocked, including for administrators. Push the workflow changes to `main`
before applying this protection so every PR can run the required checks.
