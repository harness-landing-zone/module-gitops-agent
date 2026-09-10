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
    identifier            = "managed_openshift"
    name                  = "Managed OpenShift"
    namespace             = "managed-openshift"
    existing_installation = false
  }

  install_helm = true
  runtime = {
    cluster_type     = "openshift"
    create_namespace = true
    release_name     = "managed-openshift"
    install_crds     = false
    values_yaml      = [file("${path.module}/values.yaml")]
  }

  app_project_mappings = {
    (var.harness_project_id) = {
      source_repos = ["https://github.com/example/platform.git"]
      destinations = [{
        namespace = "managed-openshift"
        server    = "https://kubernetes.default.svc"
      }]
    }
  }
}
