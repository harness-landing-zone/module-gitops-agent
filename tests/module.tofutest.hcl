# Plan-only checks. All providers are mocked; no credentials or cluster are used.
mock_provider "harness" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}

override_resource {
  target = harness_platform_gitops_agent.this
  values = {
    agent_token         = "mock-agent-token"
    prefixed_identifier = "org.test_agent"
  }
}

variables {
  agent = {
    account_id = "test-account"
    org_id     = "test_org"
    identifier = "test_agent"
    name       = "Test Agent"
    namespace  = "gitops-test"
  }
  install_helm = true
  runtime = {
    create_namespace = true
  }
  app_project_mappings = {
    Platform_Test = {
      source_repos = ["https://github.com/example/platform.git"]
      destinations = [{
        namespace = "gitops-test"
        server    = "https://kubernetes.default.svc"
      }]
    }
  }
}

run "managed_kubernetes" {
  command = plan

  assert {
    condition     = helm_release.agent[0].chart == "gitops-helm" && helm_release.agent[0].version == "1.2.10"
    error_message = "Managed Kubernetes must select the managed chart and its default version."
  }
  assert {
    condition     = length(kubernetes_namespace_v1.agent) == 1 && kubernetes_secret_v1.agent_token[0].metadata[0].namespace == "gitops-test"
    error_message = "The managed example must own its namespace and place the token Secret there."
  }
  assert {
    condition     = output.argo_project_names["Platform_Test"] == "platform-test" && harness_platform_gitops_app_project_mapping.this["Platform_Test"].project_id == "Platform_Test"
    error_message = "Argo names must be normalized without changing the Harness project identifier."
  }
  assert {
    condition     = !yamldecode(output.helm_values_yaml[2]).harness.createClusterRoles && !yamldecode(output.helm_values_yaml[2])["argo-cd"].crds.install
    error_message = "The default runtime must stay namespaced and leave shared CRDs untouched."
  }
}

run "managed_openshift" {
  command = plan

  variables {
    agent = {
      account_id        = "test-account"
      org_id            = "test_org"
      project_id        = "Platform_Test"
      identifier        = "test_agent"
      name              = "Test Agent"
      namespace         = "gitops-test"
      high_availability = true
    }
    runtime = {
      cluster_type     = "openshift"
      create_namespace = true
      values_yaml      = [file("./examples/managed-openshift/values.yaml")]
    }
  }

  assert {
    condition     = yamldecode(output.helm_values_yaml[1]).agent.openshift.enabled && yamldecode(output.helm_values_yaml[1])["argo-cd"].redis.securityContext.runAsUser == null
    error_message = "OpenShift must enable its compatibility values and remove Redis's fixed UID."
  }
  assert {
    condition     = yamldecode(output.helm_values_yaml[2]).agent.resources.requests.memory == "512Mi" && yamldecode(output.helm_values_yaml[3]).agent.replicas == 3
    error_message = "Example sizing must precede the final identity and HA settings."
  }
  assert {
    condition     = harness_platform_gitops_agent.this.project_id == "Platform_Test" && harness_platform_gitops_app_project_mapping.this["Platform_Test"].project_id == "Platform_Test"
    error_message = "The project-scoped agent must map to its own Harness project."
  }
}

run "byo_argocd" {
  command = plan

  variables {
    agent = {
      account_id            = "test-account"
      org_id                = "test_org"
      project_id            = "Platform_Test"
      identifier            = "test_agent"
      name                  = "Test Agent"
      namespace             = "argocd"
      existing_installation = true
    }
    runtime = {
      cluster_type = "openshift"
    }
    app_project_mappings = {}
  }

  assert {
    condition     = helm_release.agent[0].chart == "gitops-helm-byoa" && helm_release.agent[0].version == "1.3.14"
    error_message = "BYO must select the BYO chart and its default version."
  }
  assert {
    condition     = length(kubernetes_namespace_v1.agent) == 0 && length(kubernetes_secret_v1.agent_token) == 1 && length(harness_platform_gitops_app_project.this) == 0 && length(harness_platform_gitops_app_project_mapping.this) == 0
    error_message = "The BYO example must reuse its namespace and leave project configuration alone."
  }
  assert {
    condition     = !yamldecode(output.helm_values_yaml[2])["argo-cd"].enabled && !yamldecode(output.helm_values_yaml[2])["argo-cd"].crds.install
    error_message = "BYO must disable bundled Argo CD and CRD installation."
  }
}

run "external_runtime" {
  command = plan

  variables {
    install_helm         = false
    app_project_mappings = {}
  }

  assert {
    condition     = length(helm_release.agent) == 0 && length(kubernetes_namespace_v1.agent) == 0 && length(kubernetes_secret_v1.agent_token) == 0 && output.runtime_release_name == null
    error_message = "External deployment must not create cluster resources or a Helm release."
  }
  assert {
    condition     = output.deployment.chart.name == "gitops-helm" && length(output.helm_values_yaml) == 3
    error_message = "External deployment must still receive a chart and its ordered values."
  }
}

run "reject_cross_project_mapping" {
  command = plan

  variables {
    agent = {
      account_id = "test-account"
      org_id     = "test_org"
      project_id = "another_project"
      identifier = "test_agent"
      name       = "Test Agent"
      namespace  = "gitops-test"
    }
  }

  # The AppProject rejection prevents its dependent mapping from being planned.
  expect_failures = [harness_platform_gitops_app_project.this["Platform_Test"]]
}

run "reject_token_in_values" {
  command = plan

  variables {
    runtime = {
      values_yaml = [yamlencode({ harness = { secrets = { agentSecret = "not-a-real-token" } } })]
    }
  }

  expect_failures = [var.runtime]
}

run "reject_token_secret_override" {
  command = plan

  variables {
    runtime = {
      values_yaml = [yamlencode({ agent = { existingSecrets = { agentToken = "different-secret" } } })]
    }
  }

  expect_failures = [var.runtime]
}
