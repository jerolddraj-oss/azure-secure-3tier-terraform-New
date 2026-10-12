# Configure GitHub Actions authentication to Azure

Use **OIDC / workload identity federation** for the preferred setup. It authenticates GitHub Actions without storing a long-lived client secret. The current validation-only workflow does not need Azure authentication; follow this guide when setting up a plan/deploy workflow.

## Recommended: OIDC

### 1. Get Azure identifiers

In the Azure Portal:
1. Open **Microsoft Entra ID → Overview** and copy **Tenant ID**.
2. Open **Subscriptions**, select your target subscription, and copy **Subscription ID**.

### 2. Create an app registration (service principal identity)

1. Open **Microsoft Entra ID → App registrations → New registration**.
2. Name it `github-azure-terraform`; choose single-tenant unless your identity architecture requires otherwise.
3. Create it and copy **Application (client) ID**.
4. The corresponding Enterprise Application/service principal is the identity to which Azure RBAC is assigned.

### 3. Add a federated credential

1. Open the app registration → **Certificates & secrets → Federated credentials → Add credential**.
2. Choose **GitHub Actions deploying Azure resources**.
3. Set:
   - Organization/user: `jerolddraj-oss`
   - Repository: `azure-secure-3tier-terraform-New`
   - Entity type: **Branch**
   - Branch: `main`
   - Credential name: `github-main-oidc`
4. Save. GitHub's issuer, subject and audience must exactly match the workflow token. For a branch-based credential the subject is normally:
   `repo:jerolddraj-oss/azure-secure-3tier-terraform-New:ref:refs/heads/main`
   and the audience is `api://AzureADTokenExchange`.
5. If you later configure GitHub Environment protection and make the deploy job target that environment, create a separate federated credential matching the environment subject shown in Entra ID.

### 4. Pre-create the deployment resource group and register providers

The Terraform root is intentionally configured to use an **existing** resource group so that permissions can be scoped to that group:
- In Azure Portal, create resource group `secure3tier-rg` in the same region you intend to use (default: `East US`).
- Ensure `resource_group_name` in `environments/prod/terraform.tfvars` matches it.
- Have a subscription administrator register these resource providers once: `Microsoft.Network`, `Microsoft.Compute`, `Microsoft.Sql`, `Microsoft.Insights`, and `Microsoft.OperationalInsights`. The Terraform provider is configured with `resource_provider_registrations = "none"` so the CI identity does not need subscription-level provider-registration rights.

### 5. Assign least-privilege Azure permissions

In the resource group **secure3tier-rg**: open **Access control (IAM) → Add role assignment** and assign **Contributor** to the app's service principal. This is a practical lab starting role for managing resources in that group; production environments should narrow permissions further based on reviewed resource operations. Contributor does not let the identity grant itself additional Azure RBAC roles.

If using the Azure Storage remote backend, assign **Storage Blob Data Contributor** on the Terraform state container (or state storage account, if container scope is not practical). The state storage account/container must exist before `terraform init`. The backend identity needs data-plane access even when infrastructure permissions are correct.

### 6. Add GitHub repository variables

Open the repository → **Settings → Secrets and variables → Actions → Variables** and add:

- `ARM_CLIENT_ID` = Entra app's Application (client) ID
- `ARM_TENANT_ID` = Tenant ID
- `ARM_SUBSCRIPTION_ID` = Subscription ID

These are identifiers, not secrets. Do not create a client secret for OIDC.

### 7. Use OIDC in a deployment job

The validation workflow intentionally doesn't log in to Azure. For a separate plan/deployment job, use `id-token: write` and the above repository variables:

```yaml
permissions:
  contents: read
  id-token: write

steps:
  - uses: actions/checkout@v4
  - uses: azure/login@v2
    with:
      client-id: ${{ vars.ARM_CLIENT_ID }}
      tenant-id: ${{ vars.ARM_TENANT_ID }}
      subscription-id: ${{ vars.ARM_SUBSCRIPTION_ID }}
  - name: Terraform init and plan
    working-directory: environments/prod
    env:
      ARM_USE_OIDC: "true"
      ARM_USE_AZUREAD: "true"
      ARM_CLIENT_ID: ${{ vars.ARM_CLIENT_ID }}
      ARM_TENANT_ID: ${{ vars.ARM_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ vars.ARM_SUBSCRIPTION_ID }}
    run: |
      terraform init -backend-config=backend.hcl
      terraform plan -out=tfplan
```

Copy `environments/prod/backend.hcl.example` to a local `backend.hcl`, set the storage account/container/resource group fields, and keep the real file untracked. It must include both `use_oidc = true` and `use_azuread_auth = true`. In GitHub Actions, either create the backend config from protected repository/environment variables or store those non-secret values as variables; never commit state or secrets.

Do not run `terraform apply` automatically from an untrusted pull request. Use a protected GitHub Environment with required reviewers, branch restrictions and an approval gate for production apply. Always review a plan first.

## Alternative: service principal client secret

Use this only if OIDC federation is not available. Client secrets are long-lived credentials and must be rotated.

1. In Microsoft Entra ID, create/select the app registration and its service principal.
2. Open **Certificates & secrets → Client secrets → New client secret**.
3. Copy the secret **Value** immediately (not the Secret ID).
4. Assign the service principal **Contributor** on the pre-created deployment resource group, and the required **Storage Blob Data Contributor** on the state container if using remote state.
5. In GitHub → **Settings → Secrets and variables → Actions → Secrets**, add:
   - `ARM_CLIENT_ID`
   - `ARM_TENANT_ID`
   - `ARM_SUBSCRIPTION_ID`
   - `ARM_CLIENT_SECRET` (the secret Value)
6. In the deployment job environment, map them to `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, and `ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}`. Remove `ARM_USE_OIDC: "true"`; do not mix a client secret and OIDC mode.
7. Never echo, commit, or place the secret in `terraform.tfvars`. Rotate it and revoke it if it may have been exposed.

## Troubleshooting

- **AADSTS70021 / federated credential not found**: exact issuer, subject, and audience mismatch; check owner/repository spelling, branch or environment subject.
- **AuthorizationFailed**: role assignment is missing or too narrow; confirm the app's service principal, target resource group scope, and allow for RBAC propagation.
- **Remote state access denied**: verify the backend has `use_oidc = true` plus `use_azuread_auth = true`, and the identity has Storage Blob Data Contributor.
- **Provider registration errors**: have a subscription admin register the required resource providers; this pipeline's provider block deliberately disables automatic registration.
- **Terraform validate passes but plan fails**: validation does not call Azure APIs. Set required SSH/TLS/SQL values, verify network SKU availability/quotas, review routes and return paths, and run a plan against a non-production subscription.

OIDC avoids static credentials, but it does not remove the need for careful RBAC, protected branches, state security, or plan review.
