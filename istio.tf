################################################################################
# Istio
# https://github.com/istio/istio/tree/master/manifests/charts/base
# https://github.com/istio/istio/tree/master/manifests/charts/istio-control/istio-discovery
################################################################################

resource "kubernetes_namespace_v1" "istio_system" {
  count = var.enable_istio ? 1 : 0

  metadata {
    name = local.istio_system_namespace
  }
}

resource "helm_release" "istio_base" {
  count = var.enable_istio ? 1 : 0

  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.istio_version
  namespace  = kubernetes_namespace_v1.istio_system[0].metadata[0].name

  depends_on = [kubernetes_namespace_v1.istio_system]
}

resource "helm_release" "istiod" {
  count = var.enable_istio ? 1 : 0

  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = kubernetes_namespace_v1.istio_system[0].metadata[0].name

  values = [
    file("${path.module}/yamls/istio-values.yaml")
  ]

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_ingress" {
  count = var.enable_istio ? 1 : 0

  name       = "istio-ingress"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = kubernetes_namespace_v1.istio_system[0].metadata[0].name

  values = [
    file("${path.module}/yamls/istio-ingress-values.yaml")
  ]

  depends_on = [helm_release.istiod]
}
