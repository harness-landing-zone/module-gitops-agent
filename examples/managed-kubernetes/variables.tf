variable "harness_account_id" {
  description = "Harness account containing the agent."
  type        = string
}

variable "harness_org_id" {
  description = "Existing Harness organization."
  type        = string
}

variable "harness_project_id" {
  description = "Existing Harness project used by this example."
  type        = string
}

variable "harness_platform_api_key" {
  description = "Harness API key supplied through TF_VAR_harness_platform_api_key or the sensitive input prompt."
  type        = string
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig used by both cluster providers."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Explicit kubeconfig context for the target cluster."
  type        = string
}
