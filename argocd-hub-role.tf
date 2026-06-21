################################################################################
# ArgoCD Hub Role (IRSA)
# Creates the ArgoCD IRSA role with ECR and EKS access
# Allows ArgoCD default service account to assume this role.
################################################################################

locals {
  # Role name standard
  hub_role_name = "${var.cluster_name}-argocd-spoke-access"
}

# 1. IAM Role
resource "aws_iam_role" "argocd_spoke_access" {
  count = var.enable_argocd ? 1 : 0
  name  = local.hub_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${local.hub_account_id}:oidc-provider/${local.oidc_provider}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:sub" = ["system:serviceaccount:${local.argocd_namespace}:argocd-application-controller", "system:serviceaccount:${local.argocd_namespace}:argocd-repo-server"]
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name      = local.hub_role_name
    Purpose   = "ArgoCD hub cluster access"
    ManagedBy = "terraform-custom-addons"
  })
}

# 2. Wildcard "Assume Any Spoke" Policy
# As requested, grants access to assume ANY role (Resource: *)
resource "aws_iam_role_policy" "argocd_assume_wildcard" {
  count = var.enable_argocd ? 1 : 0
  name  = "argocd-assume-any-spoke"
  role  = aws_iam_role.argocd_spoke_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeAnySpoke"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "*"
    }]
  })
}

# 3. EKS Describe Policy
# Allows listing clusters (needed for K8s auth construction)
resource "aws_iam_role_policy" "argocd_eks_describe" {
  count = var.enable_argocd ? 1 : 0
  name  = "argocd-eks-describe"
  role  = aws_iam_role.argocd_spoke_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DescribeEKS"
      Effect   = "Allow"
      Action   = "eks:DescribeCluster"
      Resource = "*"
    }]
  })
}

# 4. ECR Access Policy
# Allows Repo Server to fetch charts from ECR
resource "aws_iam_role_policy" "argocd_ecr_access" {
  count = var.enable_argocd ? 1 : 0
  name  = "argocd-ecr-access"
  role  = aws_iam_role.argocd_spoke_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:GetRepositoryPolicy"
      ]
      Resource = "*"
    }]
  })
}
