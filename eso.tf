################################################################################
# External Secrets Operator (ESO)
# Installed on the orchestrator cluster to pull platform secrets
# (ArgoCD Git credentials, Backstage config, etc.) from AWS Secrets Manager
# and SSM Parameter Store via IRSA.
#
# ECR pull-secret distribution for BU clusters is a spoke-cluster concern
# and will live in the BU cluster module, not here.
################################################################################

locals {
  eso_namespace           = "external-secrets"
  eso_serviceaccount_name = "eso-service-account"
  eso_role_name           = "${var.cluster_name}-eso"
}

################################################################################
# 1. IRSA Role — Secrets Manager + SSM access
################################################################################

resource "aws_iam_role" "eso" {
  count = var.enable_eso ? 1 : 0
  name  = local.eso_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.cluster_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:sub" = "system:serviceaccount:${local.eso_namespace}:${local.eso_serviceaccount_name}"
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name      = local.eso_role_name
    Purpose   = "ESO orchestrator IRSA"
    ManagedBy = "terraform-custom-addons"
  })
}

resource "aws_iam_role_policy" "eso_secrets_access" {
  count = var.enable_eso ? 1 : 0
  name  = "eso-secrets-access"
  role  = aws_iam_role.eso[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMParameterStore"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# 2. Kubernetes Namespace
################################################################################

resource "kubernetes_namespace_v1" "eso" {
  count = var.enable_eso ? 1 : 0

  metadata {
    name = local.eso_namespace
    labels = {
      name = local.eso_namespace
    }
  }
}

################################################################################
# 3. Helm Release — External Secrets Operator
################################################################################

resource "helm_release" "external_secrets" {
  count = var.enable_eso ? 1 : 0

  name            = "external-secrets"
  repository      = "https://charts.external-secrets.io"
  chart           = "external-secrets"
  version         = var.eso_helm_version
  namespace       = kubernetes_namespace_v1.eso[0].metadata[0].name
  cleanup_on_fail = true

  values = [
    templatefile("${path.module}/yamls/external-secrets-values.yaml", {
      eso_irsa_arn_annotation = jsonencode({
        "eks.amazonaws.com/role-arn" = aws_iam_role.eso[0].arn
      })
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.eso,
    helm_release.istiod,
    helm_release.argocd,
  ]
}
