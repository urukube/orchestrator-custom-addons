################################################################################
# Istio Outputs
################################################################################

output "istio_base_release_name" {
  description = "Name of the Istio Base Helm release"
  value       = try(helm_release.istio_base[0].name, null)
}

output "istiod_release_name" {
  description = "Name of the Istiod Helm release"
  value       = try(helm_release.istiod[0].name, null)
}

output "istio_system_namespace" {
  description = "Namespace where Istio is installed"
  value       = try(kubernetes_namespace_v1.istio_system[0].metadata[0].name, null)
}

################################################################################
# ArgoCD Outputs
################################################################################

output "argocd_release_name" {
  description = "Name of the ArgoCD Helm release"
  value       = try(helm_release.argocd[0].name, null)
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = try(helm_release.argocd[0].namespace, null)
}

################################################################################
# Prometheus Outputs
################################################################################

output "prometheus_release_name" {
  description = "Name of the Prometheus Helm release"
  value       = try(helm_release.prometheus[0].name, null)
}

output "prometheus_namespace" {
  description = "Namespace where Prometheus is installed"
  value       = try(helm_release.prometheus[0].namespace, null)
}

################################################################################
# Kiali Outputs
################################################################################

output "kiali_release_name" {
  description = "Name of the Kiali Helm release"
  value       = try(helm_release.kiali[0].name, null)
}

output "kiali_namespace" {
  description = "Namespace where Kiali is installed"
  value       = try(helm_release.kiali[0].namespace, null)
}

################################################################################
# Spoke ArgoCD Role Outputs
################################################################################

output "argocd_spoke_role_arn" {
  description = "IAM role ARN for hub ArgoCD to assume (only for spoke clusters)"
  value       = try(aws_iam_role.argocd_hub_assumable[0].arn, null)
}

output "argocd_spoke_role_name" {
  description = "IAM role name for hub ArgoCD to assume (only for spoke clusters)"
  value       = try(aws_iam_role.argocd_hub_assumable[0].name, null)
}
