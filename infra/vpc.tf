# =============================================================================
# VPC Configuration
# =============================================================================
# Creates a new VPC when var.vpc_id is not provided.
# The VPC includes:
#   - 2 Public Subnets (for Langfuse Web with public IP)
#   - 2 Private Subnets (for Worker, ClickHouse, RDS, ElastiCache)
#   - Internet Gateway (for public subnet internet access)
#
# NAT Gateway is disabled by default. Private subnets use VPC Endpoints for
# AWS service access, and can optionally use NAT for external API egress.
# See vpc_endpoints.tf for endpoint definitions.
#
# When var.vpc_id is provided, this module is skipped and existing VPC is used.
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# VPC
# =============================================================================
resource "aws_vpc" "main" {
  count = local.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.service_name}-vpc"
  }
}

# =============================================================================
# Internet Gateway (for public subnets)
# =============================================================================
resource "aws_internet_gateway" "main" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "${var.service_name}-igw"
  }
}

# =============================================================================
# Public Subnets
# =============================================================================
resource "aws_subnet" "public" {
  count = local.create_vpc ? length(local.azs) : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.service_name}-public-${local.azs[count.index]}"
    Type = "public"
  }
}

resource "aws_route_table" "public" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "${var.service_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = local.create_vpc ? length(local.azs) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# =============================================================================
# Private Subnets
# =============================================================================
# NAT Gateway is optional. By default, VPC Endpoints are used for AWS service access:
#   - ECR API/DKR: Container image pull
#   - CloudWatch Logs: Log delivery
#   - Secrets Manager: Secret retrieval
#   - S3: Gateway endpoint (defined in modules/langfuse/s3.tf)
# =============================================================================
resource "aws_subnet" "private" {
  count = local.create_vpc ? length(local.azs) : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + length(local.azs))
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.service_name}-private-${local.azs[count.index]}"
    Type = "private"
  }
}

resource "aws_route_table" "private" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  # No default route by default. aws_route.private_nat adds one when NAT is enabled.

  tags = {
    Name = "${var.service_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = local.create_vpc ? length(local.azs) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# =============================================================================
# NAT Gateway (optional)
# =============================================================================
# When enable_nat_gateway is true, private subnets can reach the internet via
# a NAT Gateway in the first public subnet. This is required for outbound calls
# to external LLM APIs (OpenAI/Anthropic/Vertex) used by LLM-as-a-Judge
# evaluators.
# =============================================================================

locals {
  enable_nat   = local.create_vpc && var.enable_nat_gateway
  nat_gw_count = local.enable_nat && length(local.azs) > 0 ? 1 : 0
}

resource "aws_eip" "nat" {
  count  = local.nat_gw_count
  domain = "vpc"

  tags = {
    Name = "${var.service_name}-nat-eip-${count.index}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count         = local.nat_gw_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.service_name}-nat-${count.index}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route" "private_nat" {
  count                  = local.nat_gw_count > 0 ? 1 : 0
  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}
