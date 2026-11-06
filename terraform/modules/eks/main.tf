# ── Cluster Security Group ─────────────────────────────────────────────────────
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane communication"
  vpc_id      = var.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-sg"
    }
  )
}

# ── EKS Cluster Control Plane ──────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )

  depends_on = [
    var.cluster_iam_policy_attachments
  ]
}

# ── OIDC Provider for IRSA ─────────────────────────────────────────────────────
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-irsa-oidc"
    }
  )
}

# ── EKS Managed Node Group (Cost-Optimized SPOT by Default) ────────────────────
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = var.instance_types
  capacity_type  = var.capacity_type
  disk_size      = var.disk_size

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    environment = lookup(var.tags, "Environment", "dev")
    node_type   = "managed"
  }

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.cluster_name}-node"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    var.node_iam_policy_attachments
  ]
}
