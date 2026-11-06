# EKS Module

Provisions the Amazon EKS cluster control plane (Kubernetes v1.30), IAM OIDC Provider for IRSA, and an EKS Managed Node Group with Spot capacity.

## Features
- **EKS Control Plane v1.30**: Private and public endpoint access enabled.
- **IAM OIDC Provider**: Configured automatically using the cluster's OIDC issuer URL to power IAM Roles for Service Accounts (IRSA).
- **Cost-Optimized Worker Nodes**: 2x `t3.medium` instances utilizing `SPOT` capacity type (saving ~70% on compute cost) with automatic scaling across 2 availability zones.
- **Topology Spread Support**: Nodes distributed across private subnets to support multi-AZ scheduling of frontend, backend, and MongoDB pods.

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `cluster_name` | Name of the EKS cluster | `string` | n/a | yes |
| `cluster_version` | Kubernetes control plane version | `string` | `"1.30"` | no |
| `vpc_id` | VPC ID where cluster resources reside | `string` | n/a | yes |
| `subnet_ids` | Private subnet IDs for cluster and nodes | `list(string)` | n/a | yes |
| `cluster_role_arn` | ARN of the EKS cluster IAM role | `string` | n/a | yes |
| `node_role_arn` | ARN of the worker node group IAM role | `string` | n/a | yes |
| `instance_types` | EC2 instance types for nodes | `list(string)` | `["t3.medium"]` | no |
| `capacity_type` | Instance capacity type (`SPOT` or `ON_DEMAND`) | `string` | `"SPOT"` | no |
| `desired_size` | Desired node count | `number` | `2` | no |
| `min_size` | Minimum node count | `number` | `2` | no |
| `max_size` | Maximum node count | `number` | `4` | no |
| `disk_size` | Node root volume in GB (`gp3`) | `number` | `20` | no |
| `tags` | Common tags applied to resources | `map(string)` | `{}` | no |

## Outputs
| Name | Description |
|------|-------------|
| `cluster_name` | Name of the EKS cluster |
| `cluster_id` | ID of the EKS cluster |
| `cluster_endpoint` | Endpoint URL for the Kubernetes API server |
| `cluster_certificate_authority_data` | Base64 encoded CA certificate |
| `cluster_security_group_id` | Security Group ID of the cluster |
| `node_group_id` | ID of the managed node group |
| `oidc_provider_arn` | ARN of the OIDC provider for IRSA |
| `oidc_provider_url` | Hostname of the OIDC provider |
