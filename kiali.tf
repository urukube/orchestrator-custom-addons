################################################################################
# Kiali
# https://github.com/kiali/helm-charts
################################################################################

resource "helm_release" "kiali" {
  count = var.enable_kiali ? 1 : 0

  name             = "kiali"
  repository       = "https://kiali.org/helm-charts"
  chart            = "kiali-server"
  version          = var.kiali_version
  namespace        = local.istio_system_namespace
  create_namespace = false
  cleanup_on_fail  = true

  values = [
    file("${path.module}/yamls/kiali-values.yaml")
  ]

  depends_on = [helm_release.istiod, helm_release.argocd, helm_release.prometheus]
}
