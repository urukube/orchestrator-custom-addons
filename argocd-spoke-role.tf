################################################################################
# ArgoCD Spoke Role (IRSA)
# Creates an IAM role that allows the hub cluster's ArgoCD to assume
# Creates an IAM role that allows the hub cluster's ArgoCD to manage this cluster
################################################################################

locals {
  # Construct the hub's ArgoCD role ARN using naming convention
  hub_argocd_role_arn = "arn:aws:iam::${local.hub_account_id}:role/${var.hub_cluster_name}-argocd-spoke-access"

  # Spoke role name with length validation
  spoke_role_name = "${var.cluster_name}-argocd-hub-assumable"
}

################################################################################
# IAM Role - Assumable by Hub's ArgoCD
################################################################################

resource "aws_iam_role" "argocd_hub_assumable" {
  count = 1

  name = local.spoke_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowHubArgoCD"
      Effect = "Allow"
      Principal = {
        AWS = local.hub_argocd_role_arn
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name      = local.spoke_role_name
    Purpose   = "ArgoCD hub cluster access"
    ManagedBy = "terraform-custom-addons"
  })

  lifecycle {
    precondition {
      condition     = var.hub_cluster_name != ""
      error_message = "hub_cluster_name must be provided for the spoke role"
    }
    precondition {
      condition     = length(local.spoke_role_name) <= 64
      error_message = "Spoke role name '${local.spoke_role_name}' exceeds 64 character limit (${length(local.spoke_role_name)} chars)"
    }
  }
}

################################################################################
# IAM Policy - EKS Describe (needed for K8s authentication)
################################################################################

resource "aws_iam_policy" "argocd_eks_describe" {
  count = 1

  name        = "${var.cluster_name}-argocd-eks-describe"
  description = "Allows EKS describe for ArgoCD authentication from hub cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DescribeEKS"
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = "arn:aws:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
    }]
  })

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-argocd-eks-describe"
    ManagedBy = "terraform-custom-addons"
  })
}

resource "aws_iam_role_policy_attachment" "argocd_eks_describe" {
  count = 1

  role       = aws_iam_role.argocd_hub_assumable[0].name
  policy_arn = aws_iam_policy.argocd_eks_describe[0].arn
}

################################################################################
# EKS Access Entry - Cluster Admin Access
# Grants the Hub ArgoCD role access to the cluster via EKS Access API
################################################################################

resource "aws_eks_access_entry" "argocd_hub_access" {
  count = 1

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.argocd_hub_assumable[0].arn
  type          = "STANDARD"

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-argocd-access-entry"
    ManagedBy = "terraform-custom-addons"
  })
}

resource "aws_eks_access_policy_association" "argocd_hub_admin" {
  count = 1

  cluster_name  = var.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.argocd_hub_assumable[0].arn

  access_scope {
    type = "cluster"
  }
}
