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

The validation workflow checks formatting and validates Terraform without Azure credentials. Review routing, firewall policy, TLS, private endpoint DNS, permissions and costs before deployment.