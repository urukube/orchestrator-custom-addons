################################################################################
# Komoplane
# A read-only UI for browsing Crossplane composite resources and claim graphs.
# https://github.com/komodorio/komoplane
#
# Requires enable_crossplane = true — reads Crossplane CRDs from the cluster.
################################################################################

resource "helm_release" "komoplane" {
  count = var.enable_komoplane ? 1 : 0

  name             = "komoplane"
  repository       = "https://helm-charts.komodor.io"
  chart            = "komoplane"
  version          = var.komoplane_version
  namespace        = local.crossplane_namespace
  create_namespace = false
  timeout          = 300
  cleanup_on_fail  = true

  values = [
    file("${path.module}/yamls/komoplane-values.yaml")
  ]

  depends_on = [
    helm_release.crossplane,
    time_sleep.wait_for_crossplane_crds,
  ]
}
