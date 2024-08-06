## Private subnet/s
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = element(split(",", var.azs), count.index)
  count             = length(var.private_subnets)

  tags = {
    Name        = "${var.name}-private-${element(split(",", var.azs), count.index)}"
    Environment = var.env
    managed_by  = "terraform"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  count  = signum(length(var.private_subnets))

  tags = {
    Name        = "${var.name}-private-${element(split(",", var.azs), count.index)}"
    Environment = var.env
    managed_by  = "terraform"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.*.id[0]
  count          = length(var.private_subnets)
}

## NAT gateway
resource "aws_eip" "nat" {
  tags = {
    Name = "${var.name}-eip"
  }
}

resource "aws_route" "nat_gateway" {
  route_table_id         = aws_route_table.private.*.id[0]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.*.id[0]
  count                  = var.nat_gateways_count
  depends_on             = [aws_route_table.private]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  count         = var.nat_gateways_count
  tags = {
    Name        = "${var.env}-nat"
    Environment = var.env
  }
}

output "route_table_id" {
  value = aws_route_table.private.*.id
}