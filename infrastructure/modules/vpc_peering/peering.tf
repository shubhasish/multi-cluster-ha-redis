resource "aws_vpc_peering_connection" "peering_connection" {
  peer_vpc_id   = var.peer_vpc_id
  vpc_id        = var.vpc_id
  auto_accept   = true

  tags = {
    Name = "VPC Peering between redis cluster 1 and redis cluster 2"
  }
    
  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "vpc1_route" {
  route_table_id         = var.vpc1_route_table_id[0]
  destination_cidr_block = var.peer_vpc_id_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peering_connection.id
}

resource "aws_route" "vpc2_route" {
  route_table_id         = var.vpc2_route_table_id[0]
  destination_cidr_block = var.vpc_id_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peering_connection.id
}