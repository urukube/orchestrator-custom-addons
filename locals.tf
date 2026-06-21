data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  partition      = data.aws_partition.current.partition
  hub_account_id = var.hub_account_id != "" ? var.hub_account_id : data.aws_caller_identity.current.account_id

  # Namespaces
  istio_system_namespace = "istio-system"
  argocd_namespace       = "argocd"
  monitoring_namespace   = "monitoring"

  # OIDC Provider for IRSA
  oidc_provider = replace(var.cluster_oidc_issuer_url, "https://", "")
}
