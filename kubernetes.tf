# Existing namespaces (especially BYO Argo) are not adopted or deleted by default.
resource "kubernetes_namespace_v1" "agent" {
  count = var.install_helm && var.runtime.create_namespace ? 1 : 0
  metadata {
    name = var.agent.namespace
  }
}

resource "kubernetes_secret_v1" "agent_token" {
  count = var.install_helm ? 1 : 0
  metadata {
    name      = "gitops-agent"
    namespace = var.agent.namespace
  }
  data = {
    GITOPS_AGENT_TOKEN = harness_platform_gitops_agent.this.agent_token
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.agent]

  lifecycle {
    precondition {
      condition     = try(length(trimspace(harness_platform_gitops_agent.this.agent_token)) > 0, false)
      error_message = "Harness returned no agent token. Obtain a valid API-issued token before installing the runtime."
    }
  }
}
