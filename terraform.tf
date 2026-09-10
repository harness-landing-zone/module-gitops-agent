terraform {
  required_version = ">= 1.9.0"
  required_providers {
    harness    = { source = "harness/harness", version = ">= 0.45.4, < 0.46.0" }
    helm       = { source = "hashicorp/helm", version = "~> 3.3" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
  }
}
