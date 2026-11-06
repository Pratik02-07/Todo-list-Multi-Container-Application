output "vpc_id" {
  description = "The ID of the provisioned VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "Primary public IP of the NAT Gateway"
  value       = aws_eip.nat[0].public_ip
}

output "nat_gateway_ips" {
  description = "List of public IPs assigned to the NAT Gateway(s)"
  value       = aws_eip.nat[*].public_ip
}
