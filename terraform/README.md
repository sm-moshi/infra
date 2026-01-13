# Terraform Infrastructure

This directory contains Terraform configurations for infrastructure provisioning.

## Structure

```
terraform/
├── environments/     # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── production/
├── modules/          # Reusable Terraform modules
├── README.md
```

## Prerequisites

- Terraform >= 1.0.0
- Appropriate cloud provider credentials
- Remote backend configured (S3, Azure Storage, GCS, etc.)

## Usage

### Initialize Terraform

```bash
cd terraform/environments/dev
terraform init
```

### Plan Changes

```bash
terraform plan -out=tfplan
```

### Apply Changes

```bash
terraform apply tfplan
```

### Destroy Resources (use with caution)

```bash
terraform destroy
```

## Best Practices

- **Never commit state files** - use remote backend with encryption
- Store state files remotely (S3, GCS, Azure Blob)
- Enable state locking
- Use workspaces for environment separation
- Use modules for reusability
- Pin provider versions
- Use `.tfvars` files for variables (never commit sensitive values)
- Run `terraform fmt` before committing
- Run `terraform validate` to check syntax

## Backend Configuration

Configure remote backend in each environment:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "env/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Variables

Use environment variables or `.tfvars` files:

```bash
# Using environment variables
export TF_VAR_region="us-east-1"

# Using .tfvars file (DO NOT commit secrets)
terraform apply -var-file="dev.tfvars"
```

## Security

- ⚠️ **Never commit** `.tfstate` files
- ⚠️ **Never commit** `.tfvars` files with secrets
- Use encrypted remote state storage
- Use Terraform Cloud/Enterprise for team collaboration
- Enable audit logging
- Review plans before applying
- Use least privilege IAM roles

## Modules

Create reusable modules:

```
modules/
├── vpc/
├── eks/
├── rds/
└── s3/
```

## Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
