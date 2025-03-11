// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = "1.5.1"
    }
    github = {
      source  = "integrations/github"
      version = "6.6.0"
    }
    rke = {
      source  = "rancher/rke"
      version = "1.7.0"
    }
  }
}
