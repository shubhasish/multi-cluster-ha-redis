resource "aws_route53_zone" "demo_cluster_route53_zone" {
  name = "${var.name}.internal"
  vpc {
    vpc_id = var.first_vpc_id
  }
}

resource "aws_route53_zone_association" "demo_cluster_route53_zone_association" {
  zone_id = aws_route53_zone.demo_cluster_route53_zone.id
  vpc_id = var.second_vpc_id
}