################################################################################
# ArgoCD Image Updater
# Automatically updates ArgoCD Applications with latest images from ECR
################################################################################

resource "helm_release" "argocd_image_updater" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd-image-updater"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  version    = "1.2.2"
  namespace  = local.argocd_namespace

  values = [
    yamlencode({
      config = {
        interval = "1m"
        registries = [
          {
            name    = "ECR"
            api_url = "https://${local.hub_account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com"
            prefix  = "${local.hub_account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com"
            ping    = true
            # Reuse the secret managed by argocd-ecr-updater CronJob
            credentials = "secret:argocd-repo-aws-ecr-${data.aws_region.current.region}"
          }
        ]
      }
    })
  ]

  depends_on = [
    helm_release.argocd
  ]
}
