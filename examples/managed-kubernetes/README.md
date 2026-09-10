# Managed Kubernetes

Creates an organization-scoped Harness GitOps agent, a dedicated namespace, a managed Argo CD Helm release, and one AppProject mapped to `harness_project_id`.

## Prerequisites

- A Kubernetes cluster with Argo CD CRDs already installed.
- An existing Harness organization and project.
- An unused `managed-kubernetes` namespace and `managed_kubernetes` agent identifier, or unique replacements in `main.tf`.
- Replace the example repository URL with your approved repository. Provision credentials separately for a private repository.

## Run

Follow [Running an example](../../README.md#running-an-example), using this directory. `main.tf` contains the provider configuration and module call; `variables.tf` defines the shared example inputs.

The mapping targets only the agent namespace. Deploying into other namespaces also requires Kubernetes permissions; adding AppProject destinations alone does not grant them.

Only set `install_crds = true` when this managed release should own the cluster's Argo CD CRDs. Destroying the example also destroys its dedicated namespace and its contents.
