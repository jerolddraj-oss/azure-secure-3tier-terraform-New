# Configure GitHub Actions authentication to Azure

## Recommended: OIDC (no client secret)

### 1. Collect Azure IDs

In Azure Portal, open **Microsoft Entra ID → Overview** and copy the **Tenant ID**. Open **Subscriptions**, select the target subscription and copy the **Subscription ID**.

### 2. Create or choose an app registration

Open **Microsoft Entra ID → App registrations → New registration**. Name it `github-azure-terraform`, select the appropriate supported account type (normally single tenant for an organization-owned workload), and create it. Copy the **Application (client) ID**. The app registration's service principal is the identity used for Azure RBAC.

### 3. Add the federated credential

Open the app registration → **Certificates & secrets → Federated credentials → Add credential**. Choose **GitHub Actions deploying Azure resources** where available.

Set:
- Organization/user: `jerolddraj-oss`
- Repository: `azure-secure-3tier-terraform-New`
- Entity type: **Branch**
- Branch: `main`
- Name: `github-main-oidc`

Save it. The issuer, subject and audience must match the workflow token; for the above branch the subject is normally `repo:jerolddraj-oss/azure-secure-3tier-terraform-New:ref:refs/heads/main` and audience is `api://AzureADTokenExchange`. If deploying from a protected environment, use the environment subject format instead and configure the same environment name in GitHub.

### 4. Assign Azure permissions

Open the subscription or, preferably, the dedicated target resource group → **Access control (IAM) → Add role assignment**. Assign a role that permits the Terraform resources you manage.

For a lab, **Contributor** at a dedicated test resource group is a common starting point; it cannot grant Microsoft Entra role assignments. Avoid giving Owner at subscription scope just to make a pipeline work. If the pipeline needs role assignments, handle that separately with a narrowly scoped administrator-approved permission. For remote state, grant the identity appropriate blob data-plane access (for example **Storage Blob Data Contributor** scoped to the state container/account) and configure the storage backend for Entra/OIDC auth.

### 5. Add GitHub repository variables

In GitHub, open **Settings → Secrets and variables → Actions → Variables** and add:
- `ARM_CLIENT_ID` = app registration Application (client) ID
- `ARM_TENANT_ID` = Microsoft Entra Tenant ID
- `ARM_SUBSCRIPTION_ID` = Azure Subscription ID

These are identifiers, not secrets. Do not add a client secret when using OIDC.

### 6. Use OIDC in a deployment workflow

The job that logs into Azure must declare `permissions: id-token: write` and `contents: read`. Use `azure/login@v2` with `client-id`, `tenant-id` and `subscription-id` from the three variables. For Terraform AzureRM provider authentication, export the corresponding `ARM_*` environment variables or configure the provider to use OIDC. Only add Azure login to a deployment job; format/validate CI does not need cloud credentials.

Recommended pattern:

```yaml
permissions:
  id-token: write
  contents: read

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
      ARM_CLIENT_ID: ${{ vars.ARM_CLIENT_ID }}
      ARM_TENANT_ID: ${{ vars.ARM_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ vars.ARM_SUBSCRIPTION_ID }}
    run: |
      terraform init -backend-config=backend.hcl
      terraform plan -out=tfplan
```

Use a configured remote backend and keep `backend.hcl` uncommitted. Do not run `apply` automatically from an untrusted pull request. Require environment approval or protected-branch review before production apply.

## Alternative: Service principal with client secret

OIDC is preferred. Only use a client secret if federation is not available.

1. In Microsoft Entra ID, create or select the app registration and its service principal.
2. Under **Certificates & secrets → Client secrets → New client secret**, create one and copy the **Value** immediately. Do not use the Secret ID.
3. Assign Azure RBAC to the service principal at a dedicated test resource-group scope, preferably starting with Contributor for a lab; reduce privileges for production.
4. In GitHub **Settings → Secrets and variables → Actions → Secrets**, create:
   - `ARM_CLIENT_ID` = application/client ID
   - `ARM_TENANT_ID` = tenant ID
   - `ARM_SUBSCRIPTION_ID` = subscription ID
   - `ARM_CLIENT_SECRET` = secret **Value**
5. For Terraform, pass these as job environment variables. Do not echo them, place them in tfvars, or commit them. Rotate and expire the secret according to your policy.

To use a service-principal secret, remove `ARM_USE_OIDC: "true"` and set `ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}` for the job. Do not configure OIDC and client-secret settings simultaneously in a confusing mixture.

## Troubleshooting

- **AADSTS70021 / federated credential not found**: issuer, subject (owner/repo, branch or environment), or audience mismatch.
- **Not authorized / AuthorizationFailed**: RBAC role is missing or assigned at the wrong scope; allow time for RBAC propagation.
- **Backend access denied**: storage blob data permissions are missing or backend auth settings do not match OIDC.
- **Terraform validate says variable not set**: ensure example variable files have safe defaults or explicitly provide validation-time values; do not solve this by committing secrets.
- **OIDC not available**: confirm the job has `id-token: write`, the run is on an allowed branch/environment, and the federated credential exactly matches its subject.

No authentication method can guarantee every deployment succeeds; verify using a plan in a non-production subscription before applying changes.
