${yamlencode({
  harness = {
    identity = {
      accountIdentifier = agent.account_id
      orgIdentifier = agent.org_id
      projectIdentifier = agent.project_id
      agentIdentifier = agent.identifier
    }
    createClusterRoles = !agent.is_namespaced
    secrets = { agentSecret = "" }
  }
  agent = {
    name = "gitops-agent"
    harnessName = agent.name
    replicas = agent.high_availability ? 3 : 1
    highAvailability = agent.high_availability
    serviceAccount = { name = "gitops-agent", create = true }
    existingSecrets = { agentToken = "gitops-agent" }
  }
  argo-cd = {
    enabled = !agent.existing_installation
    createClusterRoles = !agent.is_namespaced
    crds = { install = runtime.install_crds, keep = true }
  }
})}
