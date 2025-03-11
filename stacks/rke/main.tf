provider "rke" {}

resource "rke_cluster" "nexus" {
  cluster_name = "nexus"

  enable_cri_dockerd = true
  ssh_agent_auth     = true

  network {
    plugin = "calico"
  }

  dynamic "nodes" {
    for_each = local.nodes

    content {
      address = nodes.key
      user    = "root"
      role    = nodes.value["roles"]
    }
  }

  authentication {
    sans = [
      "k8s-home-prod.int.sajbox.net",
      "192.168.10.10"
    ]
  }

  ingress {
    provider = "none"
  }

  addons_include = [
    "https://kube-vip.io/manifests/rbac.yaml",
    "./manifests/kube-vip-pod.yaml",
    "https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml",
    "./manifests/kube-vip-cm.yaml"
  ]
}

# create a local file containing the kubeconfig
resource "local_file" "kubeconfig" {
  content  = rke_cluster.nexus.kube_config_yaml
  filename = "kubeconfig.yaml"
}
