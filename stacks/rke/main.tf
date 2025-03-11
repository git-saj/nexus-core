provider "rke" {}

resource "rke_cluster" "nexus" {
  cluster_name = "nexus"

  enable_cri_dockerd = true
  ssh_agent_auth     = true

  dynamic "nodes" {
    for_each = local.nodes

    content {
      address = nodes.key
      user    = "root"
      role    = nodes.value["roles"]
    }
  }
}

# create a local file containing the kubeconfig
resource "local_file" "kubeconfig" {
  content  = rke_cluster.nexus.kube_config_yaml
  filename = "kubeconfig.yaml"
}
