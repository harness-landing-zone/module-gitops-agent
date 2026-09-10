locals {
  # Keep layers separate: Helm performs a recursive merge; HCL merge() is shallow.
  values_yaml = concat(
    [file("${path.module}/values/base.yaml"), file("${path.module}/values/${var.runtime.cluster_type == "openshift" ? "openshift" : "generic"}.yaml")],
    var.runtime.values_yaml,
    [templatefile("${path.module}/templates/identity.yaml.tpl", { agent = var.agent, runtime = var.runtime })],
  )
  deployment = {
    schema_version = 1
    agent = {
      account_id          = var.agent.account_id
      org_id              = var.agent.org_id
      project_id          = var.agent.project_id
      identifier          = harness_platform_gitops_agent.this.identifier
      prefixed_identifier = harness_platform_gitops_agent.this.prefixed_identifier
      namespace           = var.agent.namespace
    }
    chart = {
      repository = var.agent.existing_installation ? "https://harness.github.io/gitops-helm-byoa/" : "https://harness.github.io/gitops-helm/"
      name       = var.agent.existing_installation ? "gitops-helm-byoa" : "gitops-helm"
      version    = coalesce(var.runtime.chart_version, var.agent.existing_installation ? "1.3.14" : "1.2.10")
    }
    release_name = var.runtime.release_name
    values_yaml  = local.values_yaml
  }
}

locals {
  # The Harness project each entry maps: the map key unless overridden.
  mapped_project_ids = {
    for key, mapping in var.app_project_mappings :
    key => trimspace(coalesce(mapping.project_id, key))
  }

  # Argo project names are Kubernetes object names: slugify the Harness project
  # identifier, and fall back to a truncated slug plus a digest of the identifier
  # when the slug exceeds the 63-character limit.
  argo_project_slugs = {
    for key, project_id in local.mapped_project_ids :
    key => trim(replace(lower(project_id), "/[^a-z0-9-]/", "-"), "-")
  }

  argo_project_name_defaults = {
    for key, slug in local.argo_project_slugs :
    key => length(slug) <= 63 ? slug : format(
      "%s-%s",
      substr(slug, 0, 54),
      substr(sha256(local.mapped_project_ids[key]), 0, 8),
    )
  }

  app_project_mappings = {
    for key, mapping in var.app_project_mappings : key => merge(mapping, {
      harness_project_id = local.mapped_project_ids[key]
      argo_project_name  = coalesce(mapping.argo_project_name, local.argo_project_name_defaults[key])
      namespace          = coalesce(mapping.namespace, var.agent.namespace)

      description = coalesce(
        mapping.description,
        "Harness project ${var.agent.org_id}/${local.mapped_project_ids[key]}.",
      )

      labels = merge(
        var.app_project_labels,
        {
          "harness.io/organization" = var.agent.org_id
          "harness.io/project"      = local.mapped_project_ids[key]
        },
        mapping.labels,
      )
    })
  }

}
