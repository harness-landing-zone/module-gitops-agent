variable "agent" {
  description = "Agent identity and registration settings. Account ID must match the caller's Harness provider."
  type = object({
    account_id            = string
    org_id                = string
    project_id            = optional(string, "")
    identifier            = string
    name                  = string
    namespace             = string
    description           = optional(string)
    tags                  = optional(map(string), {})
    high_availability     = optional(bool, false)
    is_namespaced         = optional(bool, true)
    existing_installation = optional(bool, false)
  })
  nullable = false
  validation {
    condition = alltrue([
      for id in [var.agent.org_id, var.agent.identifier] :
      can(regex("^[A-Za-z_][A-Za-z0-9_$]{0,127}$", id))
    ]) && (var.agent.project_id == "" || can(regex("^[A-Za-z_][A-Za-z0-9_$]{0,127}$", var.agent.project_id)))
    error_message = "Agent, organization and project identifiers must be valid Harness identifiers."
  }
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.agent.namespace))
    error_message = "namespace must be a DNS label of at most 63 characters."
  }
  validation {
    condition     = length(trimspace(var.agent.account_id)) > 0 && length(trimspace(var.agent.name)) > 0 && length(var.agent.name) <= 128
    error_message = "account_id and name are required; name must be at most 128 characters."
  }
}

variable "runtime" {
  description = "Runtime configuration. Values documents are non-secret Helm overrides, in increasing precedence."
  type = object({
    cluster_type     = optional(string, "generic")
    chart_version    = optional(string)
    create_namespace = optional(bool, false)
    release_name     = optional(string, "harness-gitops-agent")
    install_crds     = optional(bool, false)
    values_yaml      = optional(list(string), [])
  })
  default  = {}
  nullable = false
  validation {
    condition     = contains(["generic", "openshift"], var.runtime.cluster_type)
    error_message = "runtime.cluster_type must be generic or openshift."
  }
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,51}[a-z0-9])?$", var.runtime.release_name)) && (var.runtime.chart_version == null || can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.runtime.chart_version)))
    error_message = "Use a valid Helm release name (maximum 53 characters) and an exact chart version."
  }
  validation {
    condition     = alltrue([for document in var.runtime.values_yaml : can(keys(yamldecode(document)))])
    error_message = "Each values_yaml entry must decode to a YAML mapping."
  }
  validation {
    # Tokens belong to the separate sensitive channel, never to portable values.
    condition = alltrue([for document in var.runtime.values_yaml :
      try(yamldecode(document).harness.secrets.agentSecret, "") == "" &&
      try(yamldecode(document).agent.existingSecrets.agentToken, "") == ""
    ])
    error_message = "Do not place agent tokens or token-secret overrides in values_yaml."
  }
}

variable "app_project_mappings" {
  description = <<-EOT
    Argo AppProject definitions and their Harness project mappings, keyed by the Harness
    project identifier that receives the mapping. Set `project_id` inside an entry to map
    a project whose identifier differs from the map key.

    Each entry creates a `harness_platform_gitops_app_project` (unless
    `create_app_project = false`, to reuse an AppProject that already exists) and a
    `harness_platform_gitops_app_project_mapping` (unless `create_mapping = false`).

    A project-scoped Agent may only map to its own project; org-scoped Agents may map to
    any project in the organization.
  EOT
  type = map(object({
    project_id        = optional(string)
    argo_project_name = optional(string)
    namespace         = optional(string)
    description       = optional(string)

    labels       = optional(map(string), {})
    annotations  = optional(map(string), {})
    finalizers   = optional(list(string))
    cluster_name = optional(string)

    source_repos                        = list(string)
    source_namespaces                   = optional(list(string))
    permit_only_project_scoped_clusters = optional(bool)

    destinations = list(object({
      name      = optional(string)
      namespace = optional(string)
      server    = optional(string)
    }))

    cluster_resource_whitelist = optional(list(object({
      group = optional(string)
      kind  = optional(string)
    })), [])
    cluster_resource_blacklist = optional(list(object({
      group = optional(string)
      kind  = optional(string)
    })), [])
    namespace_resource_whitelist = optional(list(object({
      group = optional(string)
      kind  = optional(string)
    })), [])
    namespace_resource_blacklist = optional(list(object({
      group = optional(string)
      kind  = optional(string)
    })), [])

    orphaned_resources = optional(object({
      warn = optional(bool, true)
      ignore = optional(list(object({
        group = optional(string)
        kind  = optional(string)
        name  = optional(string)
      })), [])
      }), {
      warn = true
    })

    roles = optional(list(object({
      name        = string
      description = string
      policies    = optional(list(string))
      groups      = optional(list(string))
    })), [])

    sync_windows = optional(list(object({
      kind         = optional(string)
      schedule     = optional(string)
      duration     = optional(string)
      applications = optional(list(string))
      namespaces   = optional(list(string))
      clusters     = optional(list(string))
      manual_sync  = optional(bool)
      time_zone    = optional(string)
    })), [])

    signature_keys = optional(list(string), [])

    create_app_project      = optional(bool, true)
    upsert                  = optional(bool, false)
    create_mapping          = optional(bool, true)
    auto_create_service_env = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for key, mapping in var.app_project_mappings :
      can(regex("^[A-Za-z_][A-Za-z0-9_$]{0,127}$", trimspace(coalesce(mapping.project_id, key))))
    ])
    error_message = "Each app_project_mappings key (or its project_id override) must be a supported Harness identifier."
  }

  validation {
    condition = alltrue([
      for key, mapping in var.app_project_mappings :
      mapping.argo_project_name == null ||
      can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", mapping.argo_project_name))
    ])
    error_message = "app_project_mappings[*].argo_project_name must be a Kubernetes DNS label of at most 63 characters."
  }

  validation {
    condition = alltrue([for mapping in values(var.app_project_mappings) :
      length(mapping.source_repos) > 0 && alltrue([for repo in mapping.source_repos : length(trimspace(repo)) > 0]) &&
      length(mapping.destinations) > 0 && alltrue([for destination in mapping.destinations :
        try(length(trimspace(destination.namespace)) > 0, false) &&
        (try(length(trimspace(destination.server)) > 0, false) || try(length(trimspace(destination.name)) > 0, false))
      ])
    ])
    error_message = "Supply nonempty repositories and destinations with a namespace and a server or cluster name."
  }
}

variable "app_project_labels" {
  description = "Labels merged into every managed Argo AppProject. Per-mapping `labels` win on conflicts."
  type        = map(string)
  default = {
    "app.kubernetes.io/managed-by" = "opentofu"
  }
}


variable "install_helm" {
  description = "Install and own the runtime release here. False leaves deployment to CD; AppProjects and mappings remain managed here."
  type        = bool
  default     = false
}
variable "helm_timeout_seconds" {
  description = "Helm installation/upgrade timeout in seconds."
  type        = number
  default     = 600
  validation {
    condition     = var.helm_timeout_seconds >= 1 && floor(var.helm_timeout_seconds) == var.helm_timeout_seconds
    error_message = "helm_timeout_seconds must be a positive integer."
  }
}
