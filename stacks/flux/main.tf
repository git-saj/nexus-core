provider "github" {}

provider "flux" {
  kubernetes = {
    host = var.rke_api_server_url

    client_certificate           = var.rke_client_cert
    client_key                   = var.rke_client_key
    client_certificate_authority = var.rke_ca_crt
  }
  git = {
    url    = "ssh://git@github.com/git-saj/nexus-core.git"
    branch = "main"
    ssh = {
      username    = "git"
      private_key = tls_private_key.this.private_key_pem
    }
  }
}

resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "this" {
  repository = "nexus-core"
  title      = "flux-bootstrap"
  key        = tls_private_key.this.public_key_openssh
  read_only  = true
}

resource "flux_bootstrap_git" "this" {
  embedded_manifests = true
  path               = "clusters/nexus"

  depends_on = [github_repository_deploy_key.this]
}
