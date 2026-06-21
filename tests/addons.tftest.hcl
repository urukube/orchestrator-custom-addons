
run "setup" {
  module {
    source = "./tests/setup"
  }
}

provider "kubernetes" {
  host                   = run.setup.cluster_endpoint
  cluster_ca_certificate = base64decode(run.setup.cluster_certificate_authority_data)
  token                  = "mock-token"
}

provider "helm" {
  kubernetes = {
    host                   = run.setup.cluster_endpoint
    cluster_ca_certificate = base64decode(run.setup.cluster_certificate_authority_data)
    token                  = "mock-token"
  }
}


run "plan" {
  command = plan

  variables {
    cluster_name                       = run.setup.cluster_name
    cluster_endpoint                   = run.setup.cluster_endpoint
    cluster_certificate_authority_data = run.setup.cluster_certificate_authority_data
    cluster_oidc_provider_arn          = run.setup.cluster_oidc_provider_arn
    cluster_oidc_issuer_url            = run.setup.cluster_oidc_issuer_url
    env                                = run.setup.env
    # vpc_id                             = run.setup.vpc_id # Custom addons dont use vpc_id currently, but keeping for consistency if needed

    # Toggles
    enable_istio      = true
    enable_argocd     = true
    enable_prometheus = true
    enable_kiali      = true

    tags = {
      bu_id  = run.setup.bu_id
      app_id = run.setup.app_id
      env    = run.setup.env
    }
  }

  # Verify Istio resources are created
  assert {
    condition     = length(helm_release.istio_base) == 1
    error_message = "Istio Base Helm release should be created"
  }

  assert {
    condition     = length(helm_release.istiod) == 1
    error_message = "Istiod Helm release should be created"
  }

  # Verify ArgoCD resource is created
  assert {
    condition     = length(helm_release.argocd) == 1
    error_message = "ArgoCD Helm release should be created"
  }

  # Verify Prometheus resource is created
  assert {
    condition     = length(helm_release.prometheus) == 1
    error_message = "Prometheus Helm release should be created"
  }

  # Verify Kiali resource is created
  assert {
    condition     = length(helm_release.kiali) == 1
    error_message = "Kiali Helm release should be created"
  }

  # Verify Istio Gateway is created
  assert {
    condition     = length(kubectl_manifest.istio_gateway) == 1
    error_message = "Istio Gateway should be created"
  }

  # Verify ArgoCD VirtualService is created
  assert {
    condition     = length(kubectl_manifest.argocd_vs) == 1
    error_message = "ArgoCD VirtualService should be created"
  }

  # Verify Kiali VirtualService is created
  assert {
    condition     = length(kubectl_manifest.kiali_vs) == 1
    error_message = "Kiali VirtualService should be created"
  }

  # Verify Prometheus VirtualService is created
  assert {
    condition     = length(kubectl_manifest.prometheus_vs) == 1
    error_message = "Prometheus VirtualService should be created"
  }
}
