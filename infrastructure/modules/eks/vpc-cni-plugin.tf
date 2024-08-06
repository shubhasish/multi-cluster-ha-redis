data "tls_certificate" "demo_eks_cluster_cert" {
  url = aws_eks_cluster.demo_eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "demo_eks_cluster_openid_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.demo_eks_cluster_cert.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.demo_eks_cluster.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "vcp-cni_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.demo_eks_cluster_openid_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.demo_eks_cluster_openid_provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "demo_eks_vpc-cni_role" {
  assume_role_policy = data.aws_iam_policy_document.vcp-cni_assume_role_policy.json
  name               = "${var.name}-vpc-cni-role"
}

resource "aws_iam_role_policy_attachment" "emo_eks_vpc-cni_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.demo_eks_vpc-cni_role.name
}

resource "aws_eks_addon" "vpc-cni_addon" {
  cluster_name = aws_eks_cluster.demo_eks_cluster.name
  addon_name   = "vpc-cni"
}

data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.demo_eks_cluster_openid_provider.arn]
    }

    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    condition {
      test     = "StringEquals"
      variable = "${aws_iam_openid_connect_provider.demo_eks_cluster_openid_provider.url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${aws_iam_openid_connect_provider.demo_eks_cluster_openid_provider.url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

  }
}

resource "aws_iam_role_policy_attachment" "AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.demo_eks_cluster.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.29.1-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
}
