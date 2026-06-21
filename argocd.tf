################################################################################
# ArgoCD
# https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
################################################################################

resource "kubernetes_namespace_v1" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name = local.argocd_namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = local.argocd_namespace
  create_namespace = false

  values = [
    templatefile("${path.module}/yamls/argocd-values.yaml", {
      domain_url          = var.domain_url
      argocd_iam_role_arn = aws_iam_role.argocd_spoke_access[0].arn
      aws_region          = data.aws_region.current.region
      aws_account_id      = local.hub_account_id
    })
  ]

  depends_on = [
    helm_release.istiod,
    kubernetes_namespace_v1.argocd
  ]
}
