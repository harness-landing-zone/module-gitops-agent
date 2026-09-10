module "gitops_agent" {
  source = "../.."
  agent = {
    account_id            = "<account-id>"
    org_id                = "example_org_id"
    identifier            = "example_identifier"
    name                  = "Example Org Agent"
    namespace             = "example-namespace"
    description           = "Example Agent."
    existing_installation = false
  }
  install_helm = true
  runtime = {
    cluster_type  = "generic"
    chart_version = "1.2.10"
    release_name  = "gitops-instance"
    install_crds  = true
    create_namespace = true
  }
  app_project_mappings = {
    GitopsTest = {
      source_repos = ["https://github.com/example.git"]
      destinations = [{
        namespace = "example-managed-gitops"
        server    = "https://kubernetes.default.svc"
      }]
    },
    Nomad = {
      source_repos = ["https://github.com/example.git"]
      destinations = [{
        namespace = "example-managed-gitops"
        server    = "https://kubernetes.default.svc"
      }]
    },
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
  account_id       = "<account-id>"
  platform_api_key = "<platform-api-key>"
}

provider "helm" {}
provider "kubernetes" {}