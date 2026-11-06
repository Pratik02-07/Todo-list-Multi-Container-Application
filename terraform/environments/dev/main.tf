# ── 1. Networking Module (VPC, Subnets, Gateways) ──────────────────────────────
module "networking" {
  source = "../../modules/networking"

  cluster_name       = var.cluster_name
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = true
  tags               = local.common_tags
}

# ── 2. IAM Module (Cluster & Node Group Roles) ─────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  cluster_name = var.cluster_name
  tags         = local.common_tags
}

# ── 3. EKS Module (Cluster Control Plane & Node Group) ─────────────────────────
module "eks" {
  source = "../../modules/eks"

  cluster_name                   = var.cluster_name
  vpc_id                         = module.networking.vpc_id
  subnet_ids                     = module.networking.private_subnet_ids
  cluster_role_arn               = module.iam.cluster_role_arn
  cluster_iam_policy_attachments = module.iam.cluster_iam_policy_attachments
  node_role_arn                  = module.iam.node_role_arn
  node_iam_policy_attachments    = module.iam.node_iam_policy_attachments
  instance_types                 = var.node_instance_types
  capacity_type                  = var.node_capacity_type
  desired_size                   = var.node_desired_size
  min_size                       = var.node_min_size
  max_size                       = var.node_max_size
  tags                           = local.common_tags

  depends_on = [module.networking, module.iam]
}

# ── 4. Add-ons Module (VPC-CNI, CoreDNS, Kube-Proxy, EBS CSI with IRSA) ────────
module "addons" {
  source = "../../modules/addons"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  tags              = local.common_tags

  depends_on = [module.eks]
}

# ── 5. AWS Load Balancer Controller Module (IRSA + Helm Release) ───────────────
module "aws_load_balancer_controller" {
  count  = var.enable_load_balancer_controller ? 1 : 0
  source = "../../modules/controllers/aws-load-balancer-controller"

  cluster_name      = module.eks.cluster_name
  vpc_id            = module.networking.vpc_id
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  tags              = local.common_tags

  depends_on = [module.eks, module.addons]
}
