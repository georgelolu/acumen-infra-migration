data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "acumen" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "acumen" {
  vpc_id = aws_vpc.acumen.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.acumen.id

  cidr_block        = "10.20.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet"
    Tier = "public"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id = aws_vpc.acumen.id

  cidr_block        = "10.20.21.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${local.name_prefix}-private-a"
    Tier = "private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id = aws_vpc.acumen.id

  cidr_block        = "10.20.22.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${local.name_prefix}-private-b"
    Tier = "private"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id = aws_vpc.acumen.id

  cidr_block        = "10.20.23.0/24"
  availability_zone = data.aws_availability_zones.available.names[2]

  tags = {
    Name = "${local.name_prefix}-private-c"
    Tier = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.acumen.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.acumen.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }

  depends_on = [
    aws_internet_gateway.acumen
  ]
}

resource "aws_nat_gateway" "acumen" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${local.name_prefix}-nat"
  }

  depends_on = [
    aws_internet_gateway.acumen
  ]
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.acumen.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.acumen.id
  }

  tags = {
    Name = "${local.name_prefix}-private-a-rt"
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.acumen.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.acumen.id
  }

  tags = {
    Name = "${local.name_prefix}-private-b-rt"
  }
}

resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.acumen.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.acumen.id
  }

  tags = {
    Name = "${local.name_prefix}-private-c-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_c.id
}
