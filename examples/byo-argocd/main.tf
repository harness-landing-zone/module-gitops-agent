terraform {
  required_version = ">= 1.9.0"

  required_providers {
    harness    = { source = "harness/harness", version = ">= 0.45.4, < 0.46.0" }
    helm       = { source = "hashicorp/helm", version = "~> 3.3" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
  }
}

provider "harness" {
  endpoint         = "https://app.harness.io/gateway"
  account_id       = var.harness_account_id
  platform_api_key = var.harness_platform_api_key
}

provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kube_context
  }
}

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kube_context
}

module "gitops_agent" {
  source = "../.."

  agent = {
    account_id            = var.harness_account_id
    org_id                = var.harness_org_id
    project_id            = var.harness_project_id
    identifier            = "byo_argocd"
    name                  = "Bring your own Argo CD"
    namespace             = "argocd"
    existing_installation = true
  }

  install_helm = true
  runtime = {
    cluster_type     = "openshift"
    create_namespace = false
    release_name     = "byo-argocd"
    install_crds     = false
  }
}
