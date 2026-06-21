################################################################################
# Crossplane IRSA Role
# Grants the Crossplane AWS provider pods an AWS identity via IRSA.
# Trust is scoped via StringLike to cover both the family provider and any
# sub-providers without needing to enumerate each service account name.
# Policy covers everything needed to provision BU clusters: EC2 (networking),
# EKS, IAM (roles + OIDC providers), KMS, S3, and cross-account STS assume
# for provisioning into separate BU AWS accounts.
################################################################################

locals {
  crossplane_role_name = "${var.cluster_name}-crossplane"
}

resource "aws_iam_role" "crossplane" {
  count = var.enable_crossplane ? 1 : 0
  name  = local.crossplane_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "${local.oidc_provider}:sub" = [
            "system:serviceaccount:${local.crossplane_namespace}:provider-aws-*",
            "system:serviceaccount:${local.crossplane_namespace}:upbound-provider-aws-*"
          ]
        }
        StringEquals = {
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name      = local.crossplane_role_name
    Purpose   = "Crossplane infrastructure provisioning IRSA"
    ManagedBy = "terraform-custom-addons"
  })
}

resource "aws_iam_role_policy" "crossplane_infra" {
  count = var.enable_crossplane ? 1 : 0
  name  = "crossplane-infra-provisioning"
  role  = aws_iam_role.crossplane[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EC2"
        Effect   = "Allow"
        Action   = ["ec2:*"]
        Resource = "*"
      },
      {
        Sid      = "EKS"
        Effect   = "Allow"
        Action   = ["eks:*"]
        Resource = "*"
      },
      {
        Sid    = "IAM"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:ListRoles",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicies",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
          "iam:TagOpenIDConnectProvider",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:DescribeKey",
          "kms:EnableKeyRotation",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:ListKeys",
          "kms:ListAliases",
          "kms:ListResourceTags",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:CreateAlias",
          "kms:DeleteAlias"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:PutBucketEncryption",
          "s3:GetBucketEncryption",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketTagging",
          "s3:GetBucketTagging",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "*"
      },
      {
        # Allows provisioning into BU accounts via cross-account roles
        Sid      = "STSCrossAccount"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "*"
      }
    ]
  })
}
