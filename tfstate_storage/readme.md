#Instructions

This module creates a resource group and storage account to be used for terraform state files in other labs. It includes an RBAC role for the deployment user to allow for future deployments to interact with the blob service.

To deploy, execute the following steps:

1. Update the example.auto.tfvars file with values for the name_prefix and location variables.
1. Run `terraform init` 
1. Run `terraform apply -auto-approve` 