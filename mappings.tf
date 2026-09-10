resource "harness_platform_gitops_app_project_mapping" "this" {
  for_each = {
    for key, mapping in local.app_project_mappings : key => mapping
    if mapping.create_mapping
  }

  org_id                  = var.agent.org_id
  project_id              = each.value.harness_project_id
  agent_id                = harness_platform_gitops_agent.this.prefixed_identifier
  argo_project_name       = each.value.argo_project_name
  auto_create_service_env = each.value.auto_create_service_env

  # The AppProject must exist in Argo CD before Harness can map a project onto it. This
  # orders the mappings behind any AppProject owned here; when they are owned by Helm
  # instead, the runtime release has to be applied first.
  depends_on = [helm_release.agent, harness_platform_gitops_app_project.this]

  lifecycle {
    precondition {
      condition     = each.value.namespace == var.agent.namespace
      error_message = "An AppProject must be in the agent namespace."
    }
    precondition {
      condition     = length(distinct([for p in values(local.app_project_mappings) : p.argo_project_name])) == length(local.app_project_mappings)
      error_message = "Each mapping must have a unique Argo project name; specify explicit names when project slugs collide."
    }
    precondition {
      condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", each.value.argo_project_name)) && length(each.value.source_repos) > 0 && length(each.value.destinations) > 0
      error_message = "Supply a valid Argo project name, source repositories and destinations."
    }

    precondition {
      condition     = var.agent.project_id == "" || each.value.harness_project_id == var.agent.project_id
      error_message = "A project-scoped GitOps Agent can only be mapped to its own Harness project."
    }
  }
}
