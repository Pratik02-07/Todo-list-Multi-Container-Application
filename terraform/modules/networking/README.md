# Networking Module

Provisions the foundational multi-AZ VPC network for the Amazon EKS cluster and application workloads.

## Features
- **VPC** with DNS resolution and hostnames enabled.
- **2 Public Subnets** tagged with `kubernetes.io/role/elb = 1` for Internet-Facing Application Load Balancers.
- **2 Private Subnets** tagged with `kubernetes.io/role/internal-elb = 1` for EKS worker nodes and internal services.
- **Cost-Optimized Egress**: Single NAT Gateway shared across private subnets for Dev environments.

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `cluster_name` | Name of the EKS cluster for naming and tag association | `string` | n/a | yes |
| `vpc_cidr` | CIDR block for the VPC | `string` | `"10.50.0.0/16"` | no |
| `availability_zones` | Availability Zones to distribute subnets | `list(string)` | `["ap-south-1a", "ap-south-1b"]` | no |
| `public_subnets` | Public subnet CIDRs | `list(string)` | `["10.50.1.0/24", "10.50.2.0/24"]` | no |
| `private_subnets` | Private subnet CIDRs | `list(string)` | `["10.50.10.0/24", "10.50.20.0/24"]` | no |
| `single_nat_gateway` | Use single NAT Gateway for cost reduction | `bool` | `true` | no |
| `tags` | Tags applied to resources | `map(string)` | `{}` | no |

## Outputs
| Name | Description |
|------|-------------|
| `vpc_id` | ID of the created VPC |
| `vpc_cidr_block` | CIDR block of the VPC |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `nat_gateway_ip` | Elastic IP assigned to NAT Gateway |
