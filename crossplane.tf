################################################################################
# Crossplane
# The infrastructure provisioning engine on the orchestrator cluster.
#
# Flow:
#   BU engineer submits an environment request via Backstage
#   → Backstage creates a Crossplane Composite Resource Claim (XRC)
#   → Crossplane reconciles the XRC against AWS (VPCs, EKS clusters, IAM roles)
#     in the target BU account via cross-account STS assume
#   → ArgoCD detects the new cluster and deploys the app-of-apps
#
# Install sequence (each stage gates on the previous CRDs being registered):
#   1. Namespace + Helm (registers Provider + DeploymentRuntimeConfig CRDs)
#   2. IRSA DeploymentRuntimeConfig (annotates provider pods)
#   3. Provider (downloads upbound/provider-family-aws; registers ProviderConfig CRD)
#   4. ProviderConfig (configures IRSA credentials)
################################################################################

locals {
  crossplane_namespace = "crossplane-system"
  crossplane_role_name = "${var.cluster_name}-crossplane"
}

################################################################################
# 1. Namespace
################################################################################

resource "kubernetes_namespace_v1" "crossplane" {
  count = var.enable_crossplane ? 1 : 0

  metadata {
    name = local.crossplane_namespace
  }
}

################################################################################
# 2. IRSA Role
# Trust is scoped to Crossplane provider service accounts via StringLike so
# both the family provider and any sub-providers automatically pick it up.
# The policy covers everything Crossplane needs to provision BU clusters:
# EC2 (networking), EKS, IAM (roles + OIDC providers), KMS, S3, and cross-
# account STS assume for provisioning into BU accounts.
################################################################################

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

################################################################################
# 3. Helm Release — Crossplane core
################################################################################

resource "helm_release" "crossplane" {
  count = var.enable_crossplane ? 1 : 0

  name             = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  chart            = "crossplane"
  version          = var.crossplane_version
  namespace        = kubernetes_namespace_v1.crossplane[0].metadata[0].name
  create_namespace = false

  depends_on = [kubernetes_namespace_v1.crossplane]
}

################################################################################
# 4. Wait for Crossplane core CRDs to register
#    (Provider, DeploymentRuntimeConfig, Composition, XRD etc.)
################################################################################

resource "time_sleep" "wait_for_crossplane_crds" {
  count = var.enable_crossplane ? 1 : 0

  depends_on      = [helm_release.crossplane]
  create_duration = "60s"
}

################################################################################
# 5. DeploymentRuntimeConfig — injects IRSA role ARN onto provider pods
################################################################################

resource "kubectl_manifest" "crossplane_runtime_config" {
  count = var.enable_crossplane ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "pkg.crossplane.io/v1beta1"
    kind       = "DeploymentRuntimeConfig"
    metadata = {
      name = "provider-aws-irsa"
    }
    spec = {
      serviceAccountTemplate = {
        metadata = {
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.crossplane[0].arn
          }
        }
      }
    }
  })

  depends_on = [time_sleep.wait_for_crossplane_crds]
}

################################################################################
# 6. AWS Provider — upbound/provider-family-aws
#    Downloads the provider package and starts the provider pod.
#    The provider pod registers ProviderConfig and all AWS resource CRDs.
################################################################################

resource "kubectl_manifest" "crossplane_provider_aws" {
  count = var.enable_crossplane ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "pkg.crossplane.io/v1"
    kind       = "Provider"
    metadata = {
      name = "upbound-provider-family-aws"
    }
    spec = {
      package = "xpkg.upbound.io/upbound/provider-family-aws:${var.crossplane_provider_aws_version}"
      runtimeConfigRef = {
        name = "provider-aws-irsa"
      }
    }
  })

  depends_on = [kubectl_manifest.crossplane_runtime_config]
}

################################################################################
# 7. Wait for the provider pod to become healthy and register ProviderConfig CRD
################################################################################

resource "time_sleep" "wait_for_provider_crds" {
  count = var.enable_crossplane ? 1 : 0

  depends_on      = [kubectl_manifest.crossplane_provider_aws]
  create_duration = "120s"
}

################################################################################
# 8. ProviderConfig — configures the AWS provider to authenticate via IRSA
################################################################################

resource "kubectl_manifest" "crossplane_provider_config" {
  count = var.enable_crossplane ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "aws.upbound.io/v1beta1"
    kind       = "ProviderConfig"
    metadata = {
      name = "default"
    }
    spec = {
      credentials = {
        source = "IRSA"
      }
    }
  })

  depends_on = [time_sleep.wait_for_provider_crds]
}
