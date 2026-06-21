resource "kubectl_manifest" "istio_gateway" {
  count = var.enable_istio ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = "istio-gateway"
      namespace = local.istio_system_namespace
    }
    spec = {
      selector = {
        istio = "ingressgateway" # Matches the label of the deployment from the chart
      }
      servers = [
        {
          port = {
            number   = 80
            name     = "http"
            protocol = "HTTP"
          }
          hosts = [var.domain_url]
        },
        {
          port = {
            number   = 443
            name     = "https"
            protocol = "HTTPS"
          }
          tls = {
            mode = "PASSTHROUGH"
          }
          hosts = [var.domain_url]
        }
      ]
    }
  })

  depends_on = [helm_release.istiod, helm_release.istio_ingress, helm_release.istio_base]
}
