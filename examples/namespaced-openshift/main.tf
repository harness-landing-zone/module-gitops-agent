module "gitops_agent" {
  source = "../.."

  agent = {
    account_id            = "<account-id>"
    org_id                = "example_org_id"
    project_id            = "example_project_id"
    identifier            = "example_managed_openshift"
    name                  = "Example Managed OpenShift Agent"
    namespace             = "example-managed-gitops"
    description           = "Managed namespaced OpenShift agent."
    existing_installation = false
  }

  install_helm = true
  runtime = {
    cluster_type     = "openshift"
    create_namespace = true
    release_name     = "example-managed-gitops"
    install_crds     = false
    values_yaml      = [file("${path.module}/managed-openshift.yaml")]
  }

  app_project_mappings = {
    platform_management = {
      source_repos = ["https://github.com/example.git"]
      destinations = [{
        namespace = "example-managed-gitops"
        server    = "https://kubernetes.default.svc"
      }]
    }
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
