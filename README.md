# Harness GitOps Agent OpenTofu Module

Registers a Harness GitOps agent and, when enabled, installs its runtime Helm chart. It supports a managed Argo CD runtime, a bring-your-own Argo CD runtime, Argo AppProjects, and Harness project mappings.

## Usage

~~~hcl
module "gitops_agent" {
  source = "<namespace>/gitops-agent/harness"
  # version = "x.y.z"

  agent = {
    account_id = var.harness_account_id
    org_id     = "example_org"
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

Configure the Harness, Helm, and Kubernetes providers in the calling root module. Keep the Harness API key in a CI secret store or in provider-supported environment variables, never in source files.

## Runtime modes

| Mode | existing_installation | Chart | Default version | Prerequisites |
| --- | --- | --- | --- | --- |
| Managed Argo CD | false | gitops-helm | 1.2.10 | Namespace and Argo CRDs, unless this release creates them |
| Bring your own Argo CD | true | gitops-helm-byoa | 1.3.14 | Working Argo CD, Redis, repo server, controllers, and Argo ConfigMaps in the same namespace |

Harness treats existing_installation as immutable. Create a new agent instead of switching an existing agent between managed and BYO modes.

For a namespaced agent where Argo CRDs already exist, set runtime.install_crds to false. Set it to true only when this managed release owns the CRDs. BYO installations never install CRDs.

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
| [examples/generic-test](examples/generic-test) | Managed Argo CD on standard Kubernetes, including two project mappings |
| [examples/namespaced-openshift](examples/namespaced-openshift) | Managed, namespaced OpenShift agent with small local-cluster resource requests |
| [examples/BYO-Argo](examples/BYO-Argo) | Agent that connects to Argo CD already installed in its namespace |

Examples are starting points. Replace every placeholder, use a unique agent identifier and namespace, and review the full plan before applying.

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

Add native OpenTofu tests under tests/*.tofutest.hcl for module behavior that does not need a real Harness account or cluster. Mock the Harness, Helm, and Kubernetes providers and use command = plan so tests only evaluate planned configuration.

~~~bash
tofu fmt -check -recursive
tofu init -backend=false
tofu validate
tofu test
~~~

Test managed and BYO chart selection, OpenShift values, namespace creation, AppProject slugging, and invalid mapping inputs. Keep live cluster and Harness acceptance tests in separate, explicitly configured environments.

## Security

OpenTofu state contains the agent token when this module creates the Kubernetes Secret. Use an encrypted remote backend with restricted access. Never commit API keys, kubeconfigs, state files, plans, or tfvars files containing credentials.
