output "deployment" {
  description = "Versioned, non-secret deployment contract shared by Helm and Harness CD."
  value       = local.deployment
}
output "deployment_yaml" {
  description = "Portable YAML form of deployment; contains no agent token."
  value       = templatefile("${path.module}/templates/deployment.yaml.tpl", { deployment = local.deployment })
}
output "agent_token" {
  description = "Bootstrap token. Sensitive outputs mask display but local state still contains the token."
  value       = sensitive(harness_platform_gitops_agent.this.agent_token)
  sensitive   = true
}

output "helm_values_yaml" {
  description = "Non-secret, ordered Helm values documents, available before registration."
  value       = local.values_yaml
}

output "argo_project_names" {
  description = "Argo project names keyed by request mapping key."
  value       = { for key, mapping in local.app_project_mappings : key => mapping.argo_project_name }
}
output "mapping_identifiers" {
  description = "Created Harness mapping identifiers."
  value       = { for key, mapping in harness_platform_gitops_app_project_mapping.this : key => mapping.identifier }
}

output "runtime_release_name" {
  description = "Helm release owned here, or null when CD owns deployment."
  value       = one(helm_release.agent[*].name)
}
