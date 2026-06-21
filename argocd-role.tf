################################################################################
# ArgoCD Orchestrator Role (IRSA)
# Creates the ArgoCD IRSA role on the orchestrator cluster.
# ArgoCD running here will assume cross-account roles in BU clusters
# (dev/prod) that are provisioned on demand — those target roles are
# created at cluster-provisioning time, not here.
################################################################################

locals {
  argocd_role_name = "${var.cluster_name}-argocd"
}

# 1. IAM Role
resource "aws_iam_role" "argocd_orchestrator" {
  count = var.enable_argocd ? 1 : 0
  name  = local.argocd_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
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
    Name      = local.argocd_role_name
    Purpose   = "ArgoCD orchestrator IRSA"
    ManagedBy = "terraform-custom-addons"
  })
}

# 2. Cross-Account Assume Policy
# Grants ArgoCD the ability to assume roles in any BU cluster account.
resource "aws_iam_role_policy" "argocd_assume_any_cluster" {
  count = var.enable_argocd ? 1 : 0
  name  = "argocd-assume-any-cluster"
  role  = aws_iam_role.argocd_orchestrator[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeAnyCluster"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "*"
    }]
  })
}

# 3. EKS Describe Policy
# Allows listing/describing clusters (needed for K8s auth construction).
resource "aws_iam_role_policy" "argocd_eks_describe" {
  count = var.enable_argocd ? 1 : 0
  name  = "argocd-eks-describe"
  role  = aws_iam_role.argocd_orchestrator[0].id

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
# Allows Repo Server to fetch charts from ECR.
resource "aws_iam_role_policy" "argocd_ecr_access" {
  count = var.enable_argocd ? 1 : 0
  name  = "argocd-ecr-access"
  role  = aws_iam_role.argocd_orchestrator[0].id

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
