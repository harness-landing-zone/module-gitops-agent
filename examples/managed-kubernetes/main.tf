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
    identifier            = "managed_kubernetes"
    name                  = "Managed Kubernetes"
    namespace             = "managed-kubernetes"
    existing_installation = false
  }

  install_helm = true
  runtime = {
    cluster_type     = "generic"
    create_namespace = true
    release_name     = "managed-kubernetes"
    install_crds     = false
  }

  app_project_mappings = {
    (var.harness_project_id) = {
      source_repos = ["https://github.com/example/platform.git"]
      destinations = [{
        namespace = "managed-kubernetes"
        server    = "https://kubernetes.default.svc"
      }]
    }
  }
}
