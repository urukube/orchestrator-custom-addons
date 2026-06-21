################################################################################
# Prometheus
# https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus
################################################################################

resource "kubernetes_namespace_v1" "monitoring" {
  count = var.enable_prometheus ? 1 : 0

  metadata {
    name = local.monitoring_namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = var.prometheus_version
  namespace        = local.monitoring_namespace
  create_namespace = false

  values = [
    templatefile("${path.module}/yamls/prometheus-values.yaml", {
      domain_url = var.domain_url
    })
  ]

  depends_on = [
    helm_release.istiod,
    kubernetes_namespace_v1.monitoring
  ]
}
