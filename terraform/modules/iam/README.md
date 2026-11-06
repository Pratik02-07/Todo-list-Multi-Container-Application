# IAM Module

Provisions the AWS Identity and Access Management (IAM) roles and managed policy attachments for the Amazon EKS cluster control plane and worker node groups.

## Managed Roles
1. **Cluster IAM Role**: Assumed by `eks.amazonaws.com` with `AmazonEKSClusterPolicy` and `AmazonEKSVPCResourceController`.
2. **Worker Node Group IAM Role**: Assumed by `ec2.amazonaws.com` with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, and `AmazonEC2ContainerRegistryReadOnly`.

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `cluster_name` | Name of the EKS cluster for role scoping | `string` | n/a | yes |
| `tags` | Common tags applied to IAM resources | `map(string)` | `{}` | no |

## Outputs
| Name | Description |
|------|-------------|
| `cluster_role_arn` | ARN of the EKS cluster control plane role |
| `cluster_role_name` | Name of the EKS cluster control plane role |
| `node_role_arn` | ARN of the worker node group role |
| `node_role_name` | Name of the worker node group role |
