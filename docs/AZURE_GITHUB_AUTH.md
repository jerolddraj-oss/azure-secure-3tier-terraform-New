# Configure GitHub Actions Authentication to Azure

**Recommended: OpenID Connect (OIDC) / workload identity federation.** It avoids a long-lived client secret. The repository's current validation workflow does not access Azure and needs no identity; use the example below when preparing a separate plan/deployment workflow.

## 1. Collect Azure identifiers

In Azure Portal:
1. Open **Microsoft Entra ID → Overview** and copy the **Tenant ID**.
2. Open **Subscriptions**, select your target subscription, and copy the **Subscription ID**.

## 2. Create an app registration for GitHub Actions

1. Open **Microsoft Entra ID → App registrations → New registration**.
2. Enter a name such as `github-azure-terraform` and normally select single-tenant.
3. Create the registration and copy **Application (client) ID**.
4. The corresponding Enterprise Application/service principal is the Azure identity to which you assign RBAC.

## 3. Configure the federated credential

For a workflow running directly from `main` (without a GitHub Environment):

1. Open the app registration → **Certificates & secrets → Federated credentials → Add credential**.
2. Choose **GitHub Actions deploying Azure resources**.
3. Enter:
   - Owner: `jerolddraj-oss`
   - Repository: `azure-secure-3tier-terraform-New`
   - Entity type: **Branch**
   - Branch: `main`
   - Name: `github-main-oidc`
4. Save. For this configuration the subject is normally `repo:jerolddraj-oss/azure-secure-3tier-terraform-New:ref:refs/heads/main` and the audience is `api://AzureADTokenExchange`. Prefer the issuer, subject, and audience values automatically populated by the Entra portal.

For a production workflow protected by a GitHub Environment, create an additional federated credential with entity type **Environment** and the exact environment name (for example `production`). The subject then uses `repo:jerolddraj-oss/azure-secure-3tier-terraform-New:environment:production`. Configure the workflow to use that environment and protect it with required reviewers. A branch-based credential and an environment-based credential have different subjects; do not mix them.

## 4. Prepare Azure before running Terraform

### Target resource group

The Terraform root intentionally targets an **existing** resource group to keep permissions narrow.

1. In Azure Portal, create `secure3tier-rg` in the target region (the example defaults to **East US**).
2. Set `resource_group_name` in your local `environments/prod/terraform.tfvars` or supply `TF_VAR_resource_group_name` in the deployment job.
3. Have a subscription administrator register these providers once: `Microsoft.Network`, `Microsoft.Compute`, `Microsoft.Sql`, `Microsoft.Insights`, and `Microsoft.OperationalInsights`. The Terraform provider has `resource_provider_registrations = "none"`, so the CI identity does not need subscription-level provider registration rights.

### Remote state

Create a Storage Account and a Blob container for Terraform state before running `terraform init`. State contains sensitive values and must not be committed.

1. Assign the GitHub app's service principal **Storage Blob Data Contributor** on the state container, or on the storage account if container scope is not practical.
2. Copy `environments/prod/backend.hcl.example` to a local untracked file named `backend.hcl` and replace the storage resource group, storage account, and container placeholders.
3. Keep both `use_oidc = true` and `use_azuread_auth = true`. The `backend.hcl` file is ignored by Git.

## 5. Assign Azure RBAC

Open **secure3tier-rg → Access control (IAM) → Add role assignment** and assign **Contributor** to the app's service principal. Contributor scoped to this resource group is a practical lab starting point; for production, reduce access based on a reviewed list of required operations. Contributor does not permit the identity to grant itself Azure RBAC roles.

Keep state access separate: the state container requires **Storage Blob Data Contributor**. An identity can have sufficient permissions on the deployment resource group and still fail `terraform init` if it lacks storage data-plane access.

## 6. Add GitHub repository variables and secrets

Go to repository **Settings → Secrets and variables → Actions**.

Add these **Variables**:
- `ARM_CLIENT_ID` = Entra app's Application (client) ID
- `ARM_TENANT_ID` = Tenant ID
- `ARM_SUBSCRIPTION_ID` = Subscription ID
- `TFSTATE_RESOURCE_GROUP` = resource group containing the state Storage Account
- `TFSTATE_STORAGE_ACCOUNT` = state Storage Account name
- `TFSTATE_CONTAINER` = state Blob container name
- `TARGET_RESOURCE_GROUP` = `secure3tier-rg`

Add these **Secrets** for the current Terraform inputs:
- `SSH_PUBLIC_KEY` = SSH public key for the Linux VM admin account
- `TLS_CERTIFICATE_PFX_BASE64` = base64-encoded PFX certificate (not the raw binary file)
- `TLS_CERTIFICATE_PASSWORD` = PFX password
- `SQL_ADMIN_PASSWORD` = unique strong SQL bootstrap password

A GitHub variable is appropriate for identifiers and non-sensitive state naming. Store passwords and certificate material as secrets or retrieve them from a secret manager. Never commit real `terraform.tfvars`, `backend.hcl`, PFX files, private keys, or state.

## 7. Example OIDC plan job

This is an example for a **separate deployment workflow**. The repository's `terraform-validate.yml` intentionally does not log into Azure. The job below uses the branch-based credential for `main`; when using the `production` GitHub Environment, add `environment: production` and configure the matching environment-based federated credential described above.

```yaml
permissions:
  contents: read
  id-token: write

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: azure/login@v2
        with:
          client-id: ${{ vars.ARM_CLIENT_ID }}
          tenant-id: ${{ vars.ARM_TENANT_ID }}
          subscription-id: ${{ vars.ARM_SUBSCRIPTION_ID }}

      - name: Prepare backend configuration
        working-directory: environments/prod
        env:
          STATE_RG: ${{ vars.TFSTATE_RESOURCE_GROUP }}
          STATE_ACCOUNT: ${{ vars.TFSTATE_STORAGE_ACCOUNT }}
          STATE_CONTAINER: ${{ vars.TFSTATE_CONTAINER }}
        run: |
          test -n "$STATE_RG" && test -n "$STATE_ACCOUNT" && test -n "$STATE_CONTAINER"
          cat > backend.hcl <<EOF
          resource_group_name  = "$STATE_RG"
          storage_account_name = "$STATE_ACCOUNT"
          container_name       = "$STATE_CONTAINER"
          key                  = "secure-3tier/prod.tfstate"
          use_oidc             = true
          use_azuread_auth     = true
          EOF

      - name: Terraform init and plan
        working-directory: environments/prod
        env:
          ARM_USE_OIDC: "true"
          ARM_USE_AZUREAD: "true"
          ARM_CLIENT_ID: ${{ vars.ARM_CLIENT_ID }}
          ARM_TENANT_ID: ${{ vars.ARM_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ vars.ARM_SUBSCRIPTION_ID }}
          TF_VAR_subscription_id: ${{ vars.ARM_SUBSCRIPTION_ID }}
          TF_VAR_resource_group_name: ${{ vars.TARGET_RESOURCE_GROUP }}
          TF_VAR_ssh_public_key: ${{ secrets.SSH_PUBLIC_KEY }}
          TF_VAR_tls_certificate_pfx_base64: ${{ secrets.TLS_CERTIFICATE_PFX_BASE64 }}
          TF_VAR_tls_certificate_password: ${{ secrets.TLS_CERTIFICATE_PASSWORD }}
          TF_VAR_sql_admin_password: ${{ secrets.SQL_ADMIN_PASSWORD }}
        run: |
          terraform init -input=false -backend-config=backend.hcl
          terraform plan -input=false -no-color
```

Notes:
- The `TF_VAR_subscription_id` variable is necessary because the root configuration uses `var.subscription_id`; `ARM_SUBSCRIPTION_ID` by itself configures the Azure provider but does not populate a Terraform input variable.
- Use a protected GitHub Environment and required approvals before adding any `terraform apply` step. Do not apply from an untrusted pull request.
- `terraform validate` checks configuration/provider schemas but does not call Azure APIs; a plan is required to discover Azure policy, quota, permissions, and region-specific issues.

## 8. Alternative: service principal client secret

Use this only if federation cannot be used. A client secret is a long-lived credential that must be rotated.

1. In Entra ID, create or select the app registration and its service principal.
2. Open **Certificates & secrets → Client secrets → New client secret** and copy its **Value** immediately (not the Secret ID).
3. Assign **Contributor** on `secure3tier-rg` and **Storage Blob Data Contributor** on the state container.
4. In GitHub → **Settings → Secrets and variables → Actions → Secrets**, add `ARM_CLIENT_SECRET` with the secret Value. Reuse the `ARM_CLIENT_ID`, `ARM_TENANT_ID`, and `ARM_SUBSCRIPTION_ID` repository variables above.
5. In the deployment workflow, set `ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}` for the Terraform step, and remove `ARM_USE_OIDC: "true"`. Do not configure both authentication methods simultaneously.
6. Never echo or commit the secret. Limit its lifetime, rotate it, and revoke it if exposure is suspected.

## Troubleshooting

- **AADSTS70021 / federated credential not found**: issuer, subject, or audience mismatch. Check owner/repository spelling and whether the workflow uses a branch or GitHub Environment subject.
- **AuthorizationFailed**: the service principal lacks the required role or it is scoped incorrectly. Verify role assignment and allow time for RBAC propagation.
- **Remote-state access denied**: verify `use_oidc = true`, `use_azuread_auth = true`, and Storage Blob Data Contributor on the state container.
- **Provider registration error**: ask a subscription administrator to register the required resource providers.
- **Plan reports missing variables**: configure the SSH key, PFX data/password, SQL password, subscription and target resource group. Keep sensitive values in GitHub Secrets, not in committed tfvars.
- **Validate passes but Azure plan fails**: this may indicate an Azure permission, policy, quota, region/SKU or runtime routing issue rather than an HCL syntax problem.

OIDC reduces static credential risk, but secure RBAC, branch protection, state security, environment approvals and plan review are still required.

## Official references

- [AzureRM provider: Service principal with OIDC](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_oidc)
- [Terraform AzureRM backend authentication](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [Azure Login action](https://github.com/Azure/login)
