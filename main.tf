resource "harness_platform_gitops_agent" "this" {
  identifier  = var.agent.identifier
  name        = var.agent.name
  description = var.agent.description
  org_id      = var.agent.org_id
  project_id  = var.agent.project_id == "" ? null : var.agent.project_id
  type        = "MANAGED_ARGO_PROVIDER"
  operator    = "ARGO"
  tags        = var.agent.tags

  metadata {
    namespace             = var.agent.namespace
    high_availability     = var.agent.high_availability
    is_namespaced         = var.agent.is_namespaced
    existing_installation = var.agent.existing_installation
  }
}

