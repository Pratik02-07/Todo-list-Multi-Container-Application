# Add-ons Module

Deploys official AWS managed Kubernetes add-ons for networking, DNS, and persistent EBS storage.

## Installed Add-ons
1. **`vpc-cni`**: Pod networking interface directly mapping AWS VPC IP addresses to Kubernetes pods.
2. **`coredns`**: In-cluster Service Discovery and DNS resolution.
3. **`kube-proxy`**: Manages Kubernetes network rules on nodes.
4. **`aws-ebs-csi-driver`**: Container Storage Interface driver supporting dynamic provisioning of AWS EBS volumes (`gp3` StorageClass) for stateful workloads like MongoDB. Uses an IRSA role with `AmazonEBSCSIDriverPolicy`.

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `cluster_name` | Name of the EKS cluster | `string` | n/a | yes |
| `oidc_provider_arn` | ARN of the cluster OIDC provider | `string` | n/a | yes |
| `oidc_provider_url` | Hostname of the cluster OIDC provider | `string` | n/a | yes |
| `tags` | Common tags applied to add-ons | `map(string)` | `{}` | no |

## Outputs
| Name | Description |
|------|-------------|
| `addon_names` | List of installed add-on names |
| `ebs_csi_role_arn` | ARN of the IAM role used by the EBS CSI driver |
