# ArgoCD VirtualService
resource "kubectl_manifest" "argocd_vs" {
  count = var.enable_argocd && var.enable_istio ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "argocd-vs"
      namespace = local.argocd_namespace
    }
    spec = {
      hosts    = [var.domain_url]
      gateways = ["${local.istio_system_namespace}/istio-gateway"]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/argocd"
              }
            }
          ]
          route = [
            {
              destination = {
                host = "argocd-server"
                port = {
                  number = 80
                }
              }
            }
          ]
        }
      ]
    }
  })
  depends_on = [helm_release.argocd, kubectl_manifest.istio_gateway]
}

# Kiali VirtualService
resource "kubectl_manifest" "kiali_vs" {
  count = var.enable_kiali && var.enable_istio ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "kiali-vs"
      namespace = local.istio_system_namespace
    }
    spec = {
      hosts    = [var.domain_url]
      gateways = ["${local.istio_system_namespace}/istio-gateway"]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/kiali"
              }
            }
          ]
          route = [
            {
              destination = {
                host = "kiali"
                port = {
                  number = 20001
                }
              }
            }
          ]
        }
      ]
    }
  })
  depends_on = [helm_release.kiali, kubectl_manifest.istio_gateway]
}

# Prometheus VirtualService
resource "kubectl_manifest" "prometheus_vs" {
  count = var.enable_prometheus && var.enable_istio ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "prometheus-vs"
      namespace = local.monitoring_namespace
    }
    spec = {
      hosts    = [var.domain_url]
      gateways = ["${local.istio_system_namespace}/istio-gateway"]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/prometheus"
              }
            }
          ]
          route = [
            {
              destination = {
                host = "prometheus-server"
                port = {
                  number = 80
                }
              }
            }
          ]
        }
      ]
    }
  })
  depends_on = [helm_release.prometheus, kubectl_manifest.istio_gateway]
}
