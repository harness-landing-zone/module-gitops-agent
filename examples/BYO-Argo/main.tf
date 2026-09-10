module "gitops_agent" {
  source = "../.."
  agent = {
    account_id            = "<account-id>"
    org_id                = "example_org_id"
    project_id            = "example_project_id"
    identifier            = "example_agent"
    name                  = "Example Agent"
    namespace             = "gitops-instance"
    description           = "This is a demo agent."
    existing_installation = true
  }
  install_helm = true
  runtime = {
    cluster_type  = "openshift"
    chart_version = "1.3.14"
    release_name  = "gitops-instance"
    install_crds  = false
  }

}


terraform {
  required_providers {
    harness = {
      source = "harness/harness"
    }
  }
}


provider "harness" {
  endpoint         = "https://app.harness.io/gateway"
  account_id       = "..."
  platform_api_key = "..."
}

provider "helm" {
  kubernetes = {}
}

provider "kubernetes" {
}
