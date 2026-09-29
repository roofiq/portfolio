# Technical guide

The portfolio uses static HTML, CSS and JavaScript, built with Hugo and deployed to Azure Static Web Apps. Terraform manages the infrastructure and GitHub Actions runs validation and deployment.

## Portfolio preview

For a quick preview without Hugo (Windows CMD or PowerShell):

```shell
python -m http.server 4173 --bind 127.0.0.1 --directory site
```

Open http://localhost:4173. For the same build used in CI, install **Hugo 0.147.9**
(standard edition) and Python 3, then run from the repository root:

```shell
hugo --minify --cleanDestinationDir
python scripts/check-site.py public
python -m http.server 4173 --bind 127.0.0.1 --directory public
```

Use `hugo server` for Hugo's live-reloading development server. Generated files
in `public/` are ignored by Git; edit the source files instead.

Content is in `site/index.html`, styles in `site/assets/style.css`, and interactions
in `site/assets/main.js`. The page includes responsive layouts, native expandable
project descriptions, email copying, visible keyboard focus, and reduced-motion
support. Fonts load from Google Fonts with local fallbacks. Experience and
certifications reflect the supplied CV; no private project repositories are linked.
## Build and deployment

The **Portfolio** workflow (`.github/workflows/infra.yml`) runs on every pull
request targeting `main`, every push to `main`, and manual runs:

- **Pull requests:** validate both Terraform roots, build with pinned Hugo
  0.147.9, check generated sections and local links/assets, and save `public/`
  as the `portfolio-site` artifact. No Azure login, apply, or deployment runs.
- **Main:** after all checks pass, enter the `production` environment, apply
  infrastructure, then publish the artifact from that same workflow run.
- **Manual runs:** choose `main` in **Actions → Portfolio → Run workflow** to
  rebuild and redeploy the current version. Other branches only run checks.

Production runs are serialized and reject stale commits before infrastructure
changes and again before site upload. A run already uploading may finish before
its successor deploys. The final job summary links to the Azure site. If deployment
fails after Terraform succeeds, the infrastructure changes remain applied; fix
any error and run the workflow on current `main` again.

Azure login uses the existing federated OIDC identity and these `production`
environment variables, created by the platform bootstrap:

| Variable | Purpose |
| --- | --- |
| `AZURE_CLIENT_ID` | Application with the production federated credential |
| `AZURE_TENANT_ID` | Microsoft Entra tenant |
| `AZURE_SUBSCRIPTION_ID` | Subscription hosting the site |
| `TF_STATE_STORAGE_ACCOUNT` | Remote Terraform state storage |

The workflow retrieves the deployment token for `swa-portfolio-prod` in
`rg-portfolio-prod` at runtime and masks it before passing it to the deployment
step. No extra GitHub deployment-token secret is required. The existing
resource-group Contributor role permits this operation. Tokens are not included
in build artifacts. PR preview environments are not created.

Deployment uses the prebuilt `public/` folder with the platform build disabled;
see [Azure build configuration](https://learn.microsoft.com/en-us/azure/static-web-apps/build-configuration)
and [deployment-token retrieval](https://learn.microsoft.com/en-us/cli/azure/staticwebapp/secrets?view=azure-cli-latest).

To roll back content, revert the relevant change through a pull request and merge
it into `main`. Old workflow runs are intentionally rejected when their commit
is no longer the current tip of `main`.

## Custom domain

Terraform binds `rglebocki.pl` to the Static Web App using TXT validation.
Azure manages the HTTPS certificate automatically; no PFX or certificate secret
is needed. DNS remains managed at the domain registrar.

After the first apply:

1. In Azure, open the Static Web App's **Custom domains → rglebocki.pl** and
   copy the full TXT verification value. Terraform does not output this token.
2. In home.pl, add a TXT record with that value and leave **Host (Opcjonalne)**
   empty to apply it to the domain root.
3. In Azure, open the Static Web App's **Overview → JSON View** and copy
   `properties.stableInboundIP`. Set the root A record to that IP, replacing any
   old root A record targeting a different host. The registrar shown supports A
   records; if it supports ALIAS/ANAME, prefer pointing that to the app's default
   hostname to retain Azure's global distribution benefits.
4. Check **Custom domains** in Azure until validation and certificate provisioning
   complete, then verify `https://rglebocki.pl` opens without certificate errors.

TXT validation is asynchronous: a successful Terraform apply does not prove that
DNS or HTTPS is ready. The deployment summary keeps linking to the default Azure
URL, which remains usable during validation. `www.rglebocki.pl` is not configured.

If `rglebocki.pl` was already added manually in Azure, import it into the initialized
Terraform backend before applying this change (replace the subscription ID):

```shell
terraform -chdir=infra import azurerm_static_web_app_custom_domain.portfolio /subscriptions/<subscription-id>/resourceGroups/rg-portfolio-prod/providers/Microsoft.Web/staticSites/swa-portfolio-prod/customDomains/rglebocki.pl
```

See [Azure apex-domain setup](https://learn.microsoft.com/en-us/azure/static-web-apps/apex-domain-external)
and the [Terraform custom-domain resource](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/static_web_app_custom_domain).

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

3. Merge the portfolio and workflow files into `main`, or run **Actions →
   Portfolio → Run workflow** on `main` once the workflow is available on GitHub.
   It provisions the Static Web App and publishes the built portfolio. Find the
   site URL in the final job summary.

For details, existing-resource imports, and local Terraform usage, see
[scripts/bootstrap.ps1](scripts/bootstrap.ps1) or run
`Get-Help .\scripts\bootstrap.ps1 -Full`.

Local platform Terraform also protects `main`: changes require a pull request,
both Terraform validation checks, the `Build portfolio` check, and resolved
review conversations. Reviewer approval is
optional so you can merge your own PRs. Force pushes and branch deletion are
blocked, including for administrators. Push the workflow changes to `main`
before applying this protection so every PR can run the required checks.


For an existing setup, first merge the new workflow and let `Build portfolio`
report a result. Then rerun the local platform Terraform plan/apply from step 2
to add that check to branch protection. Editing the Terraform file alone does
not change the live GitHub rule; the workflow applies only the `infra/` root.

