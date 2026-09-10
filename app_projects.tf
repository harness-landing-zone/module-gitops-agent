resource "harness_platform_gitops_app_project" "this" {
  for_each = {
    for key, mapping in local.app_project_mappings : key => mapping
    if mapping.create_app_project
  }

  agent_id   = harness_platform_gitops_agent.this.prefixed_identifier
  org_id     = var.agent.org_id
  project_id = var.agent.project_id == "" ? null : var.agent.project_id
  upsert     = each.value.upsert

  project {
    metadata {
      name        = each.value.argo_project_name
      namespace   = each.value.namespace
      labels      = each.value.labels
      annotations = length(each.value.annotations) > 0 ? each.value.annotations : null
      finalizers  = each.value.finalizers

      cluster_name = (
        each.value.cluster_name != null && trimspace(coalesce(each.value.cluster_name, "")) != ""
        ? each.value.cluster_name
        : null
      )
    }

    spec {
      description                         = each.value.description
      source_repos                        = each.value.source_repos
      source_namespaces                   = each.value.source_namespaces
      permit_only_project_scoped_clusters = each.value.permit_only_project_scoped_clusters

      dynamic "destinations" {
        for_each = each.value.destinations
        content {
          name      = destinations.value.name
          namespace = destinations.value.namespace
          server    = destinations.value.server
        }
      }

      dynamic "cluster_resource_whitelist" {
        for_each = each.value.cluster_resource_whitelist
        content {
          group = cluster_resource_whitelist.value.group
          kind  = cluster_resource_whitelist.value.kind
        }
      }

      dynamic "cluster_resource_blacklist" {
        for_each = each.value.cluster_resource_blacklist
        content {
          group = cluster_resource_blacklist.value.group
          kind  = cluster_resource_blacklist.value.kind
        }
      }

      dynamic "namespace_resource_whitelist" {
        for_each = each.value.namespace_resource_whitelist
        content {
          group = namespace_resource_whitelist.value.group
          kind  = namespace_resource_whitelist.value.kind
        }
      }

      dynamic "namespace_resource_blacklist" {
        for_each = each.value.namespace_resource_blacklist
        content {
          group = namespace_resource_blacklist.value.group
          kind  = namespace_resource_blacklist.value.kind
        }
      }

      dynamic "orphaned_resources" {
        for_each = each.value.orphaned_resources != null ? [each.value.orphaned_resources] : []
        content {
          warn = orphaned_resources.value.warn

          dynamic "ignore" {
            for_each = orphaned_resources.value.ignore
            content {
              group = ignore.value.group
              kind  = ignore.value.kind
              name  = ignore.value.name
            }
          }
        }
      }

      dynamic "roles" {
        for_each = { for role in each.value.roles : role.name => role }
        content {
          name        = roles.value.name
          description = roles.value.description
          policies    = roles.value.policies
          groups      = roles.value.groups
        }
      }

      dynamic "sync_windows" {
        for_each = each.value.sync_windows
        content {
          kind         = sync_windows.value.kind
          schedule     = sync_windows.value.schedule
          duration     = sync_windows.value.duration
          applications = sync_windows.value.applications
          namespaces   = sync_windows.value.namespaces
          clusters     = sync_windows.value.clusters
          manual_sync  = sync_windows.value.manual_sync
          time_zone    = sync_windows.value.time_zone
        }
      }

      dynamic "signature_keys" {
        for_each = toset(each.value.signature_keys)
        content {
          key_id = signature_keys.value
        }
      }
    }
  }

  depends_on = [helm_release.agent]

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
      error_message = "A project-scoped GitOps Agent can only own an AppProject for its own Harness project."
    }
  }
}

