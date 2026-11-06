# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.cluster_name}-vpc"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# ── Internet Gateway ──────────────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-igw"
    }
  )
}

# ── Public Subnets ────────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.cluster_name}-public-${var.availability_zones[count.index]}"
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# ── Private Subnets ───────────────────────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.cluster_name}-private-${var.availability_zones[count.index]}"
      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# ── Elastic IP for NAT Gateway ────────────────────────────────────────────────
locals {
  nat_gateway_count = var.single_nat_gateway ? 1 : length(var.public_subnets)
}

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-nat-eip-${count.index}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ── NAT Gateway(s) (Single for Dev or Multi-AZ for Prod) ──────────────────────
resource "aws_nat_gateway" "main" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-nat-${count.index}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ── Public Route Table ────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Table(s) ────────────────────────────────────────────────────
resource "aws_route_table" "private" {
  count  = local.nat_gateway_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-private-rt-${count.index}"
    }
  )
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}
