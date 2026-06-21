# Mock setup for testing
# This provides mock values for the required cluster inputs

output "cluster_name" {
  value = "test-cluster"
}

output "cluster_endpoint" {
  value = "https://mock-endpoint.eks.amazonaws.com"
}

output "cluster_certificate_authority_data" {
  value = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1vY2sgQ2VydGlmaWNhdGUgRGF0YQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
}

output "cluster_oidc_provider_arn" {
  value = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
}

output "cluster_oidc_issuer_url" {
  value = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
}

output "vpc_id" {
  value = "vpc-0123456789abcdef0"
}

output "region" {
  value = "us-east-1"
}

output "bu_id" {
  value = "example-bu"
}

output "app_id" {
  value = "example-app"
}

output "env" {
  value = "dev"
}

output "hub_cluster_name" {
  value = "hub-test-cluster"
}
