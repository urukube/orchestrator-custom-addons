################################################################################
# ESO ExternalSecrets — sync AWS Secrets Manager paths into Kubernetes secrets
#
# github-token  → argocd-github-token (argocd ns) — used by ApplicationSet SCM provider
# admin-password → argocd-secret (argocd ns, merge) — ArgoCD admin login
#
# IMPORTANT: platform/argocd/admin-password must be stored as a bcrypt hash in
# Secrets Manager, not plaintext. ArgoCD reads admin.password as a bcrypt hash.
# Generate with: htpasswd -bnBC 10 "" <password> | tr -d ':\n'
################################################################################

resource "kubectl_manifest" "eso_argocd_github_token" {
  count             = var.enable_eso && var.enable_argocd ? 1 : 0
  server_side_apply = true
  wait              = true

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "argocd-github-token"
      namespace = local.argocd_namespace
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "ClusterSecretStore"
        name = "aws-secrets-manager"
      }
      target = {
        name           = "argocd-github-token"
        creationPolicy = "Owner"
      }
      data = [{
        secretKey = "token"
        remoteRef = {
          key = "platform/github/github-token"
        }
      }]
    }
  })

  depends_on = [
    kubectl_manifest.eso_cluster_secret_store,
    helm_release.argocd,
  ]
}

resource "kubectl_manifest" "eso_argocd_admin_password" {
  count             = var.enable_eso && var.enable_argocd ? 1 : 0
  server_side_apply = true
  wait              = true

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "argocd-admin-password"
      namespace = local.argocd_namespace
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "ClusterSecretStore"
        name = "aws-secrets-manager"
      }
      target = {
        name           = "argocd-secret"
        creationPolicy = "Merge"
      }
      data = [{
        secretKey = "admin.password"
        remoteRef = {
          key = "platform/argocd/admin-password"
        }
      }]
    }
  })

  depends_on = [
    kubectl_manifest.eso_cluster_secret_store,
    helm_release.argocd,
  ]
}
