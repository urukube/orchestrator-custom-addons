
resource "kubernetes_ingress_class_v1" "istio" {
  count = var.enable_istio ? 1 : 0
  metadata {
    name = "istio"
    labels = {
      "app.kubernetes.io/component" = "ingress-gateway"
      "app.kubernetes.io/instance"  = "istio-ingress"
    }
  }

  spec {
    controller = "istio.io/ingress-controller"
  }

  depends_on = [helm_release.istiod]
}
