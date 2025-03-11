terramate {
  config {
    experiments = [
      "outputs-sharing"
    ]
  }
}

# generate the hcl for the terraform.tf consisting of backend and provider definitions
generate_hcl "_generated_terraform.tf" {
  condition = tm_fileexists("stack.tm.hcl")
  content {
    terraform {
      # configure the terraform version from globals
      required_version = global.terraform_version

      required_providers {
        rke = {
          source  = "rancher/rke"
          version = global.provider_versions.rke
        }
        flux = {
          source  = "fluxcd/flux"
          version = global.provider_versions.flux
        }
        github = {
          source = "integrations/github"
          version = global.provider_versions.github
        }
      }
    }
  }
}

# generate the hcl for the locals.tf consisting of the stack specific locals
generate_hcl "_generated_locals.tf" {
  condition = tm_fileexists("stack.tm.hcl")
  content {
    # expose globals as terraform locals, uses the file structure to build the resource_prefix and provide tags
    locals {
      nodes = global.nodes
    }
  }
}

# create the default sharing_backend
sharing_backend "default" {
  type     = terraform
  filename = "_generated_sharing_backend.tf"
  command  = ["terraform", "output", "-json"]
}
