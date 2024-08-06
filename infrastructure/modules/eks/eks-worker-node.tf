resource "aws_iam_role" "aws_eks_node_group_role" {
  name = "${var.name}-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_security_group" "eks_node_sg" {
  name        = "${var.name}-eks-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = var.cross_vpc_cidr_block
    self = true
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = var.vpc_cidr_block
    self = true
  }
  tags = {
    Name = "${var.name}-eks-node-sg"
  }
}

resource "aws_iam_role_policy_attachment" "demo_eks_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.aws_eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "demo_eks_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.aws_eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "demo_eks_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.aws_eks_node_group_role.name
}

resource "aws_eks_node_group" "demo_node_group" {
  cluster_name    = aws_eks_cluster.demo_eks_cluster.name
  node_group_name = "${var.name}-node-group-role"
  node_role_arn   = aws_iam_role.aws_eks_node_group_role.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.demo_eks_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.demo_eks_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.demo_eks_AmazonEC2ContainerRegistryReadOnly,
  ]
}