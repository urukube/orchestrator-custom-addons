
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "AIDAEXAMPLE"
    }
  }

  mock_data "aws_region" {
    defaults = {
      id     = "us-east-1"
      name   = "us-east-1"
      region = "us-east-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      id         = "aws"
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
}

mock_provider "helm" {}

mock_provider "kubernetes" {}

mock_provider "kubectl" {}

mock_provider "time" {}

mock_provider "random" {}

run "setup" {
  module {
    source = "./tests/setup"
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

    # Toggles
    enable_istio      = true
    enable_argocd     = true
    enable_prometheus = true
    enable_kiali      = true
    enable_eso        = true
    enable_ecr        = true
    enable_crossplane = true

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

  assert {
    condition     = length(kubernetes_secret_v1.argocd_redis) == 1
    error_message = "ArgoCD redis secret should be pre-created by Terraform"
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

  # Verify ArgoCD IRSA role is created
  assert {
    condition     = length(aws_iam_role.argocd_orchestrator) == 1
    error_message = "ArgoCD orchestrator IRSA role should be created"
  }

  # Verify ESO resources are created
  assert {
    condition     = length(aws_iam_role.eso) == 1
    error_message = "ESO IRSA role should be created"
  }

  assert {
    condition     = length(helm_release.external_secrets) == 1
    error_message = "ESO Helm release should be created"
  }

  # Verify ECR cross-account role is created
  assert {
    condition     = length(aws_iam_role.ecr_cross_account) == 1
    error_message = "ECR cross-account pull role should be created"
  }

  # Verify Crossplane resources are created
  assert {
    condition     = length(helm_release.crossplane) == 1
    error_message = "Crossplane Helm release should be created"
  }

  assert {
    condition     = length(aws_iam_role.crossplane) == 1
    error_message = "Crossplane IRSA role should be created"
  }

  assert {
    condition     = length(kubectl_manifest.crossplane_provider_aws) == 1
    error_message = "Crossplane AWS provider should be created"
  }

  assert {
    condition     = length(kubectl_manifest.crossplane_provider_config) == 1
    error_message = "Crossplane ProviderConfig should be created"
  }
}
