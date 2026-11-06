# AWS Load Balancer Controller Module

Deploys the official AWS Load Balancer Controller onto the Amazon EKS cluster using an IRSA (IAM Roles for Service Accounts) IAM role and the official Helm chart.

## Features
- **Least-Privilege IRSA Role**: Controller pods assume AWS IAM permissions via Kubernetes ServiceAccount tokens.
- **Automated ALB / NLB Provisioning**: Translates Kubernetes `Ingress` resources (like `k8s/overlays/eks/ingress.yaml`) into AWS Application Load Balancers.
- **Direct Pod Target Routing (`target-type: ip`)**: Enables low-latency routing directly to pod IP addresses across VPC subnets.

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `cluster_name` | Name of the EKS cluster | `string` | n/a | yes |
| `vpc_id` | VPC ID where cluster resources reside | `string` | n/a | yes |
| `aws_region` | AWS region for the controller | `string` | `"ap-south-1"` | no |
| `oidc_provider_arn` | ARN of the cluster OIDC provider | `string` | n/a | yes |
| `oidc_provider_url` | Hostname of the cluster OIDC provider | `string` | n/a | yes |
| `chart_version` | Helm chart version | `string` | `"1.8.1"` | no |
| `tags` | Common tags applied to resources | `map(string)` | `{}` | no |

## Outputs
| Name | Description |
|------|-------------|
| `role_arn` | ARN of the controller's IAM role |
| `policy_arn` | ARN of the controller's IAM policy |
| `service_account_name` | Name of the Kubernetes ServiceAccount |
| `release_name` | Name of the deployed Helm release |
| `release_status` | Status of the deployed Helm release |
