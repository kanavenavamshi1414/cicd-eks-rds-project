# =========================================================
# AVAILABILITY ZONES
# =========================================================

data "aws_availability_zones" "available" {
  state = "available"
}


# =========================================================
# VPC
# =========================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name                                        = "${var.project_name}-vpc"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }
}


# =========================================================
# INTERNET GATEWAY
# =========================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}


# =========================================================
# PUBLIC SUBNETS
# =========================================================

resource "aws_subnet" "public" {
  count = 2

  vpc_id = aws_vpc.main.id

  cidr_block = cidrsubnet(
    var.vpc_cidr,
    8,
    count.index
  )

  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.project_name}-public-${count.index + 1}"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}


# =========================================================
# PRIVATE SUBNETS
# =========================================================

resource "aws_subnet" "private" {
  count = 2

  vpc_id = aws_vpc.main.id

  cidr_block = cidrsubnet(
    var.vpc_cidr,
    8,
    count.index + 10
  )

  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = false

  tags = {
    Name                                        = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}


# =========================================================
# PUBLIC ROUTE TABLE
# =========================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}


# =========================================================
# PUBLIC INTERNET ROUTE
# =========================================================

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}


# =========================================================
# PUBLIC SUBNET ROUTE TABLE ASSOCIATION
# =========================================================

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id = aws_subnet.public[count.index].id

  route_table_id = aws_route_table.public.id
}


# =========================================================
# ELASTIC IP FOR NAT GATEWAY
# =========================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}


# =========================================================
# NAT GATEWAY
# =========================================================

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id

  # NAT Gateway must be in PUBLIC subnet
  subnet_id = aws_subnet.public[0].id

  depends_on = [
    aws_internet_gateway.main,
    aws_route.public_internet
  ]

  tags = {
    Name = "${var.project_name}-nat"
  }
}


# =========================================================
# PRIVATE ROUTE TABLE
# =========================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}


# =========================================================
# PRIVATE ROUTE THROUGH NAT GATEWAY
# =========================================================

resource "aws_route" "private_nat" {
  route_table_id = aws_route_table.private.id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.main.id

  depends_on = [
    aws_nat_gateway.main
  ]
}


# =========================================================
# PRIVATE SUBNET ROUTE TABLE ASSOCIATION
# =========================================================

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id = aws_subnet.private[count.index].id

  route_table_id = aws_route_table.private.id
}
