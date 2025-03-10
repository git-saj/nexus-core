terraform {
  required_providers {
    rke = {
      source  = "rancher/rke"
      version = "1.7.0"
    }
  }
}
# Configure RKE provider
provider "rke" {}

# Create a new RKE cluster using arguments
resource "rke_cluster" "foo2" {
  enable_cri_dockerd = true
  ssh_agent_auth     = true
  nodes {
    address = "192.168.10.102"
    user    = "root"
    role    = ["controlplane", "worker", "etcd"]
  }
  nodes {
    address = "192.168.10.103"
    user    = "root"
    role    = ["controlplane", "etcd"]
  }
  upgrade_strategy {
    drain                  = true
    max_unavailable_worker = "20%"
  }

  depends_on = [
    module.deploy
  ]
}

# store the rke kube_config_yaml in vault
resource "vault_kv_secret_v2" "kubeconfig" {
  mount               = "secret"
  name                = "kubeconfig"
  delete_all_versions = true
  data_json = jsonencode({
    kubeconfig = rke_cluster.foo2.kube_config_yaml
  })
}
