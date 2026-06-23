################################################################################
# ArgoCD ECR Secret Updater
# Creates an IRSA role and a CronJob to periodically refresh ECR credentials
# in the argocd-repo-aws-ecr-us-east-1 secret.
################################################################################

locals {
  ecr_updater_name      = "argocd-ecr-updater"
  ecr_secret_name       = "argocd-repo-aws-ecr-${data.aws_region.current.region}"
  ecr_updater_role_name = "${var.cluster_name}-argocd-ecr-updater"
}



# 2. IAM Role for ECR Updater (IRSA)
resource "aws_iam_role" "argocd_ecr_updater" {
  count = var.enable_argocd ? 1 : 0
  name  = local.ecr_updater_role_name

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
          "${local.oidc_provider}:sub" = "system:serviceaccount:${local.argocd_namespace}:${local.ecr_updater_name}"
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name      = local.ecr_updater_role_name
    Purpose   = "ArgoCD ECR credential updater"
    ManagedBy = "terraform-custom-addons"
  })
}

# 2. IAM Policy for ECR Authorization
resource "aws_iam_role_policy" "argocd_ecr_updater_policy" {
  count = var.enable_argocd ? 1 : 0
  name  = "argocd-ecr-updater-policy"
  role  = aws_iam_role.argocd_ecr_updater[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetRepositoryPolicy"
      ]
      Resource = "*"
    }]
  })
}

# 3. Service Account
resource "kubernetes_service_account_v1" "argocd_ecr_updater" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name      = local.ecr_updater_name
    namespace = local.argocd_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argocd_ecr_updater[0].arn
    }
  }

  depends_on = [
    kubernetes_namespace_v1.argocd,
    helm_release.argocd,
  ]
}

# 4. Role and RoleBinding to allow patching secrets
resource "kubernetes_role_v1" "argocd_secret_patcher" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name      = "argocd-secret-patcher"
    namespace = local.argocd_namespace
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    verbs          = ["get", "patch"]
    resource_names = [local.ecr_secret_name]
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_role_binding_v1" "argocd_secret_patcher" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name      = "argocd-secret-patcher-binding"
    namespace = local.argocd_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.argocd_secret_patcher[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.argocd_ecr_updater[0].metadata[0].name
    namespace = local.argocd_namespace
  }

  depends_on = [helm_release.argocd]
}

# 5. CronJob
resource "kubernetes_cron_job_v1" "argocd_ecr_updater" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name      = local.ecr_updater_name
    namespace = local.argocd_namespace
  }

  spec {
    schedule                      = "0 */6 * * *" # Every 6 hours
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 1

    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            service_account_name = kubernetes_service_account_v1.argocd_ecr_updater[0].metadata[0].name
            restart_policy       = "OnFailure"

            container {
              name              = "updater"
              image             = "amazon/aws-cli:latest"
              image_pull_policy = "IfNotPresent"

              command = ["/bin/sh", "-c"]
              args = [<<EOT
                # Install kubectl
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                chmod +x kubectl
                mv kubectl /usr/local/bin/

                # Get Token
                TOKEN=$(aws ecr get-login-password --region ${data.aws_region.current.region})

                # Create Patch
                # Note: We use string concatenation for JSON to avoid escaping hell
                PATCH="{\"data\":{\"password\":\"$(echo -n $TOKEN | base64 | tr -d '\n')\",\"username\":\"$(echo -n 'AWS' | base64 | tr -d '\n')\"}}"

                # Apply Patch
                kubectl patch secret ${local.ecr_secret_name} -n ${local.argocd_namespace} -p "$PATCH"

                echo "Secret patched successfully"
              EOT
              ]
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}
