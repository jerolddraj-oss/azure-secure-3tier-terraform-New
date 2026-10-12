# Azure Secure 3-Tier Terraform

Modular Azure Web/App/SQL three-tier starter stack using Terraform and GitHub Actions.

## Layout

```text
.
├── .github/workflows/terraform-validate.yml
├── docs/AZURE_GITHUB_AUTH.md
├── environments/prod/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── backend.hcl.example
└── modules/
    ├── hub-network/
    ├── spoke-network/
    ├── hub-peering/
    ├── firewall/
    ├── routes/
    ├── security/
    ├── workload-vms/
    ├── application-gateway/
    ├── sql-private/
    └── monitoring/
```

## GitHub Actions

The validation workflow formats the Terraform files in its temporary runner workspace, initializes the production configuration with the Azure backend disabled, and runs `terraform validate`. It does **not** deploy resources or require Azure credentials.

The AzureRM and Random provider versions are pinned to the versions validated in GitHub Actions. Review `docs/AZURE_GITHUB_AUTH.md` for step-by-step Azure OIDC setup, least-privilege role assignments, remote state requirements, and the alternative service-principal client-secret method.

## Before deployment

Create the target resource group and remote-state storage before running Terraform. Set the required SSH public key, TLS PFX data/password, and SQL administrator password through a protected secret mechanism. Review firewall routing and egress, Private Endpoint DNS, TLS certificate sourcing, region/SKU support, quotas, and estimated costs. Validate a plan in a non-production subscription before applying.
