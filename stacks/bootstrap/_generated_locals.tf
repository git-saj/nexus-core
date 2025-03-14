// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  nodes = {
    "k8s-home-prod-002.int.sajbox.net" = {
      name = "k8s002"
      nixos_anywhere = {
        disko_main_device = "/dev/nvme0n1"
        enable            = false
        instance_id       = 1
      }
      roles = [
        "controlplane",
        "worker",
        "etcd",
      ]
    }
    "k8s-home-prod-003.int.sajbox.net" = {
      name = "k8s003"
      nixos_anywhere = {
        enable = false
      }
      roles = [
        "controlplane",
        "etcd",
      ]
    }
  }
}
