################################################################################
# ECR Cross-Account Pull Role
# Created in the orchestrator account so BU clusters (in separate AWS accounts)
# can assume it to pull images from ECR.
# Trust policy lists the orchestrator account root as a placeholder — add each
# BU account principal here (or migrate to an aws:PrincipalOrgID condition)
# when BU clusters are onboarded.
################################################################################

locals {
  ecr_cross_account_role_name = "${var.cluster_name}-ecr-pull"
}

resource "aws_iam_role" "ecr_cross_account" {
  count = var.enable_ecr ? 1 : 0

  name = local.ecr_cross_account_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = local.ecr_cross_account_role_name
    Purpose   = "Cross-account ECR pull for BU clusters"
    ManagedBy = "terraform-custom-addons"
  })
}

resource "aws_iam_policy" "ecr_cross_account" {
  count = var.enable_ecr ? 1 : 0

  name        = "${var.cluster_name}-ecr-pull-policy"
  description = "Allows ECR read access for BU clusters pulling from the orchestrator registry"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-ecr-pull-policy"
    ManagedBy = "terraform-custom-addons"
  })
}

resource "aws_iam_role_policy_attachment" "ecr_cross_account" {
  count = var.enable_ecr ? 1 : 0

  role       = aws_iam_role.ecr_cross_account[0].name
  policy_arn = aws_iam_policy.ecr_cross_account[0].arn
}
