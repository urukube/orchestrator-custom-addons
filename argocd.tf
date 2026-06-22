################################################################################
# ArgoCD
# https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
################################################################################

resource "kubernetes_namespace_v1" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name   = local.argocd_namespace
    labels = {}
  }
}

resource "random_password" "argocd_redis" {
  count   = var.enable_argocd ? 1 : 0
  length  = 32
  special = false
}

# Pre-create the redis secret so the Helm pre-install hook job is always a no-op.
# The hook job checks whether the secret exists before creating it — if it exists,
# it exits 0 immediately. This prevents a stuck job from leaving ArgoCD undeployable.
resource "kubernetes_secret_v1" "argocd_redis" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name      = "argocd-redis"
    namespace = kubernetes_namespace_v1.argocd[0].metadata[0].name
  }

  data = {
    auth = random_password.argocd_redis[0].result
  }

  depends_on = [kubernetes_namespace_v1.argocd]
}

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = local.argocd_namespace
  create_namespace = false
  timeout          = 600
  cleanup_on_fail  = true

  values = [
    templatefile("${path.module}/yamls/argocd-values.yaml", {
      domain_url          = var.domain_url
      argocd_iam_role_arn = aws_iam_role.argocd_orchestrator[0].arn
      aws_region          = data.aws_region.current.region
      aws_account_id      = data.aws_caller_identity.current.account_id
    })
  ]

  depends_on = [
    helm_release.istiod,
    kubernetes_namespace_v1.argocd,
    kubernetes_secret_v1.argocd_redis,
  ]
}
