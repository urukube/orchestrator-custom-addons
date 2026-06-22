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
# 2. Helm Release — Crossplane core
################################################################################

resource "helm_release" "crossplane" {
  count = var.enable_crossplane ? 1 : 0

  name             = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  chart            = "crossplane"
  version          = var.crossplane_version
  namespace        = kubernetes_namespace_v1.crossplane[0].metadata[0].name
  create_namespace = false
  timeout          = 600

  depends_on = [kubernetes_namespace_v1.crossplane]
}

################################################################################
# 3. Wait for Crossplane core CRDs to register
#    (Provider, DeploymentRuntimeConfig, Composition, XRD etc.)
################################################################################

resource "time_sleep" "wait_for_crossplane_crds" {
  count = var.enable_crossplane ? 1 : 0

  depends_on      = [helm_release.crossplane]
  create_duration = "60s"
}

################################################################################
# 4. DeploymentRuntimeConfig — injects IRSA role ARN onto provider pods
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
# 5. AWS Provider — upbound/provider-family-aws
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
# 6. Wait for the provider pod to become healthy and register ProviderConfig CRD
################################################################################

resource "time_sleep" "wait_for_provider_crds" {
  count = var.enable_crossplane ? 1 : 0

  depends_on      = [kubectl_manifest.crossplane_provider_aws]
  create_duration = "120s"
}

################################################################################
# 7. ProviderConfig — configures the AWS provider to authenticate via IRSA
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
