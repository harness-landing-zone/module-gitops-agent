# Bring your own Argo CD

Creates a project-scoped Harness GitOps agent and installs the BYO agent chart alongside an existing Argo CD installation. It does not create AppProjects or Harness project mappings.

## Prerequisites

- A working Argo CD installation in the `argocd` namespace, including its controllers, Redis, repo server, ConfigMaps, and CRDs. Set the namespace in `main.tf` to match your installation.
- An existing Harness organization and project, and an unused `byo_argocd` agent identifier.
- This example selects OpenShift compatibility. Set `cluster_type = "generic"` for standard Kubernetes.

## Run

Follow [Running an example](../../README.md#running-an-example), changing the directory to `examples/byo-argocd`. `main.tf` contains the provider configuration and module call; `variables.tf` defines the shared example inputs.

The example keeps namespace creation and CRD installation disabled. It owns the agent's Helm release and token Secret, while the existing Argo CD installation remains separately managed.

`argocd-values.yaml` is an optional starting point for a separate Argo CD installation on OpenShift. The agent module does not load or deploy it. Review chart compatibility and resource sizing before using it to prepare a test instance.
