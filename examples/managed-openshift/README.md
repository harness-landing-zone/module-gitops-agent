# Managed OpenShift

Creates a project-scoped Harness GitOps agent, a dedicated namespace, a managed Argo CD Helm release, and an AppProject mapped to that same Harness project.

## Prerequisites

- An OpenShift cluster with Argo CD CRDs already installed and suitable SCC permissions and quota.
- An existing Harness organization and project.
- An unused `managed-openshift` namespace and `managed_openshift` agent identifier, or unique replacements in `main.tf`.
- Replace the example repository URL with your approved repository. Provision credentials separately for a private repository.

## Run

Follow [Running an example](../../README.md#running-an-example), changing the directory to `examples/managed-openshift`. `main.tf` contains the provider configuration and module call; `variables.tf` defines the shared example inputs.

`values.yaml` supplies small resource requests for local testing. Review sizing for your cluster. The example leaves shared CRDs untouched and maps only the agent namespace; access to other namespaces needs separate Kubernetes permissions.

Destroying the example also destroys its dedicated namespace and its contents.
