################################################################################
# ECR IAM Role for Hub Account
################################################################################

locals {
  ecr_hub_role_name = "ecr-hub-role"
}

resource "aws_iam_role" "ecr_hub_role" {
  count = var.enable_argocd ? 1 : 0

  name = local.ecr_hub_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.hub_account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = local.ecr_hub_role_name
    Purpose   = "ECR access from Hub account"
    ManagedBy = "terraform-custom-addons"
  })
}

resource "aws_iam_policy" "ecr_hub_policy" {
  count = var.enable_argocd ? 1 : 0

  name        = "ecr-hub-policy"
  description = "Allows full ECR access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "ecr-hub-policy"
    ManagedBy = "terraform-custom-addons"
  })
}

resource "aws_iam_role_policy_attachment" "ecr_hub_policy_attachment" {
  count = var.enable_argocd ? 1 : 0

  role       = aws_iam_role.ecr_hub_role[0].name
  policy_arn = aws_iam_policy.ecr_hub_policy[0].arn
}
