################ORG INFO##########################
variable "bu_id" {
  description = "Business Unit"
  type        = string
  default     = null
}

variable "app_id" {
  description = "application Unit"
  type        = string
  default     = null
}

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|prod|test)$", var.env))
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "domain_url" {
  description = "Base domain URL for the platform (e.g., orbitcluster.platform.com, xyz.company.com)"
  type        = string
  default     = ""
}

################CLUSTER INFO######################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster API server"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data for the cluster"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA (IAM Roles for Service Accounts)"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "URL of the OIDC issuer for the EKS cluster"
  type        = string
}

##################################################

################ADDON VERSIONS####################

variable "enable_istio" {
  description = "Enable Istio addon"
  type        = bool
  default     = false
}

variable "istio_version" {
  description = "Version of the Istio Helm chart"
  type        = string
  default     = "1.30.1"
}


variable "enable_kiali" {
  description = "Enable Kiali addon"
  type        = bool
  default     = false
}

variable "kiali_version" {
  description = "Version of the Kiali Helm chart"
  type        = string
  default     = "2.26.0"
}

variable "enable_argocd" {
  description = "Enable ArgoCD addon"
  type        = bool
  default     = false
}

variable "argocd_version" {
  description = "Version of the ArgoCD Helm chart"
  type        = string
  default     = "9.6.0"
}

variable "enable_prometheus" {
  description = "Enable Prometheus addon"
  type        = bool
  default     = false
}

variable "prometheus_version" {
  description = "Version of the Prometheus Helm chart"
  type        = string
  default     = "29.13.0"
}

##################################################

################COMMON CONFIG#####################

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

##################################################

################ESO CONFIG########################

variable "eso_helm_version" {
  description = "Version of the External Secrets Operator Helm chart"
  type        = string
  default     = "2.6.0"
}

##################################################

################HUB-SPOKE CONFIG##################

variable "hub_cluster_name" {
  description = "Name of the hub EKS cluster. Required for the spoke role trust policy."
  type        = string
  default     = ""

  validation {
    condition     = var.hub_cluster_name == "" || can(regex("^[a-zA-Z0-9-]+$", var.hub_cluster_name))
    error_message = "hub_cluster_name must contain only alphanumeric characters and hyphens"
  }
}

variable "hub_account_id" {
  description = "AWS account ID where the hub cluster resides. Defaults to current account if not specified."
  type        = string
  default     = ""

  validation {
    condition     = var.hub_account_id == "" || can(regex("^[0-9]{12}$", var.hub_account_id))
    error_message = "hub_account_id must be a 12-digit AWS account ID"
  }
}

##################################################
