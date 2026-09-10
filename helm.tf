resource "helm_release" "agent" {
  count            = var.install_helm ? 1 : 0
  name             = local.deployment.release_name
  repository       = local.deployment.chart.repository
  chart            = local.deployment.chart.name
  version          = local.deployment.chart.version
  namespace        = local.deployment.agent.namespace
  create_namespace = false
  atomic           = true
  wait             = true
  wait_for_jobs    = true
  timeout          = var.helm_timeout_seconds

  values     = local.deployment.values_yaml
  depends_on = [kubernetes_secret_v1.agent_token]
}
