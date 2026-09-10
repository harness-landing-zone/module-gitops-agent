# Harness GitOps Agent OpenTofu Module

Registers a Harness GitOps agent and, when enabled, installs its runtime Helm chart. It supports a managed Argo CD runtime, a bring-your-own Argo CD runtime, Argo AppProjects, and Harness project mappings.

## Before you start

- Use OpenTofu 1.9 or later and an existing Harness organization. Project-scoped agents and mappings also need an existing Harness project.
- Supply a Harness API key with access to the target resources. The examples accept it as a sensitive input; do not put it in a configuration file.
- For Helm installation, configure both the Helm and Kubernetes providers against the same cluster and context.
- These examples assume Argo CD CRDs already exist. Only a managed installation that owns the CRDs should enable `runtime.install_crds`.

The examples use a Harness SaaS endpoint in their provider configuration and server endpoints from `values/base.yaml`. Review those endpoints for your environment.

## Quick start

This example creates an organization-scoped agent and its managed runtime. Configure the providers in your calling root; the [managed Kubernetes example](examples/managed-kubernetes) includes the complete provider and input configuration.

~~~hcl
module "gitops_agent" {
  source = "git::https://github.com/harness-landing-zone/module-gitops-agent.git?ref=v0.1.0"

  agent = {
    account_id = var.harness_account_id
    org_id     = var.harness_org_id
    identifier = "platform_gitops"
    name       = "Platform GitOps"
    namespace  = "platform-gitops"
  }

  install_helm = true
  runtime = {
    cluster_type     = "generic"
    create_namespace = true
    install_crds     = false
  }

  app_project_mappings = {
    platform = {
      source_repos = ["https://github.com/example/platform.git"]
      destinations = [{
        namespace = "platform-gitops"
        server    = "https://kubernetes.default.svc"
      }]
    }
  }
}
~~~

Replace the `platform` mapping key with your existing Harness project identifier and the repository URL with your approved repository. The destination is the agent namespace so this example does not assume access to additional namespaces.

## Runtime modes

| Mode | existing_installation | Chart | Default version | Prerequisites |
| --- | --- | --- | --- | --- |
| Managed Argo CD | false | gitops-helm | 1.2.10 | Namespace and Argo CRDs, unless this release creates them |
| Bring your own Argo CD | true | gitops-helm-byoa | 1.3.14 | Working Argo CD, Redis, repo server, controllers, and Argo ConfigMaps in the same namespace |

Choose `agent.existing_installation` when creating the agent; changing an existing agent between managed and BYO modes is not covered by these examples or tests.

For a namespaced agent where Argo CRDs already exist, keep `runtime.install_crds = false`. Set it to true only when this managed release owns the CRDs. The BYO example keeps it false and reuses an existing namespace and Argo CD installation.

## Resource ownership

With `install_helm = true`, the module owns the Helm release and the `gitops-agent` token Secret. It also owns the agent namespace when `runtime.create_namespace = true`; destroying that namespace can delete everything in it.

With `install_helm = false` (the default), it creates the Harness registration and exposes the deployment configuration and sensitive token for an external deployment process. It does not create a namespace, token Secret, or Helm release. AppProjects and mappings remain enabled for entries that request them, so the external runtime must be available before those resources can be created. The IDP lifecycle integration is still to be validated.

The module does not create workload namespaces or grant access to additional destination namespaces. Namespace access, repository credentials, and shared CRDs remain the caller's responsibility.

## OpenShift

Set runtime.cluster_type to openshift. The module enables OpenShift support for the agent and managed Argo CD, removes Redis's fixed UID, and omits disabled repo-server plugin containers that use fixed UIDs. The caller remains responsible for cluster SCC, quota, and production resource sizing.

## Helm values

The module passes Helm values in this order. Later documents override earlier ones.

| Order | Source | Intended use |
| --- | --- | --- |
| 1 | Published chart defaults | Chart-maintained defaults |
| 2 | values/base.yaml | Module-wide agent and Harness defaults |
| 3 | values/generic.yaml or values/openshift.yaml | Cluster platform compatibility |
| 4 | runtime.values_yaml | Caller image, resources, Argo, proxy, and organisation overrides |
| 5 | templates/identity.yaml.tpl | Identity, token Secret name, HA, namespace mode, and CRD setting |

Do not put the agent token or token-secret settings in runtime.values_yaml. When install_helm is true, the module creates Secret gitops-agent with key GITOPS_AGENT_TOKEN from the Harness agent token and configures Helm to read it.

Lists replace earlier lists during Helm's merge. Preserve the entries you still need when overriding a list-valued chart setting.

## AppProject mappings

Each app_project_mappings entry creates an Argo AppProject and a Harness mapping by default. source_repos and at least one destination are required. A project-scoped agent can map only its own Harness project; omit agent.project_id for an organisation-scoped agent that maps multiple projects.

The Argo controller needs Kubernetes access to every destination namespace. Defining an AppProject does not grant that access.

## Examples

| Directory | Purpose |
| --- | --- |
| [managed-kubernetes](examples/managed-kubernetes) | Organization-scoped managed agent on Kubernetes, with one project mapping |
| [managed-openshift](examples/managed-openshift) | Project-scoped managed agent on OpenShift, with one mapping and small resource requests |
| [byo-argocd](examples/byo-argocd) | Project-scoped agent connected to existing Argo CD on OpenShift; no new AppProjects or mappings |

Every example uses the same `main.tf` / `variables.tf` / `README.md` layout and input names. They reference `../..` to test the module in this checkout. If you copy an example outside this repository, use the versioned Git source from the quick start.

### Running an example

From the module repository root:

~~~bash
cd examples/managed-kubernetes
export TF_VAR_harness_account_id="your-account-id"
export TF_VAR_harness_org_id="your_org"
export TF_VAR_harness_project_id="your_project"
export TF_VAR_kube_context="your-cluster-context"

tofu init
tofu validate
tofu plan
~~~

OpenTofu prompts for `harness_platform_api_key` as a sensitive input. For automation, inject `TF_VAR_harness_platform_api_key` from your secret store. Both cluster providers use `~/.kube/config` by default; set `TF_VAR_kubeconfig_path` to use another file.

Review the example's agent identifier, namespace, repository URL, and prerequisites before planning. Use a unique agent identifier and namespace for each managed installation; BYO must use the namespace of the existing Argo CD. Run `tofu apply` only when you are ready to provision the reviewed configuration. These commands use real credentials; the tests below do not.

## Requirements

| Name | Version |
| --- | --- |
| OpenTofu | >= 1.9.0 |
| Harness provider | >= 0.45.4, < 0.46.0 |
| Helm provider | ~> 3.3 |
| Kubernetes provider | ~> 2.38 |

## Providers

| Name | Source |
| --- | --- |
| Harness | harness/harness |
| Helm | hashicorp/helm |
| Kubernetes | hashicorp/kubernetes |

## Resources

| Name | Created when |
| --- | --- |
| harness_platform_gitops_agent.this | Always |
| helm_release.agent | install_helm is true |
| kubernetes_secret_v1.agent_token | install_helm is true |
| kubernetes_namespace_v1.agent | install_helm and runtime.create_namespace are true |
| harness_platform_gitops_app_project.this | Each mapping with create_app_project true |
| harness_platform_gitops_app_project_mapping.this | Each mapping with create_mapping true |

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| agent | Harness agent identity, scope, namespace, HA, tags, and BYO selection | object | n/a | yes |
| runtime | Chart version, platform, namespace creation, CRD ownership, release name, and Helm values | object | {} | no |
| app_project_mappings | AppProjects and Harness mappings keyed by Harness project identifier | map(object) | {} | no |
| app_project_labels | Labels added to every managed AppProject | map(string) | { app.kubernetes.io/managed-by = opentofu } | no |
| install_helm | Install and own the Helm runtime release | bool | false | no |
| helm_timeout_seconds | Helm install or upgrade timeout in seconds | number | 600 | no |

See [variables.tf](variables.tf) for complete nested object schemas and validation rules.

## Outputs

| Name | Description |
| --- | --- |
| deployment | Versioned deployment contract without the token |
| deployment_yaml | YAML form of the deployment contract without the token |
| agent_token | Sensitive Harness agent token |
| helm_values_yaml | Ordered non-secret Helm values documents |
| argo_project_names | Argo AppProject names keyed by mapping key |
| mapping_identifiers | Harness mapping identifiers keyed by mapping key |
| runtime_release_name | Helm release name, or null when Helm is not installed by this module |

## Testing

The native tests in [tests/module.tofutest.hcl](tests/module.tofutest.hcl) use mocked Harness, Helm, and Kubernetes providers and `command = plan`. Provider downloads require network access during initialization; the tests need no API key or kubeconfig and create no live resources.

~~~bash
tofu fmt -check -recursive
tofu init -backend=false
tofu validate
tofu test
~~~

The named scenarios match the examples: `managed_kubernetes`, `managed_openshift`, and `byo_argocd`. Additional checks cover external runtime ownership, mapping restrictions, and token-value rejection. They validate planned module configuration, not chart installation, agent connectivity, or the IDP pipeline lifecycle. Live acceptance testing remains separate.

To validate an example's provider and input configuration, run `tofu init -backend=false` and `tofu validate` in its directory. Validation does not require real input values or provision resources.

## Security

The Harness registration and sensitive output can put the agent token in OpenTofu state even when Helm installation is disabled. `sensitive` masks display; it does not remove values from state. Use an encrypted remote backend with restricted access. Never commit API keys, kubeconfigs, state files, plans, or tfvars files containing credentials.
