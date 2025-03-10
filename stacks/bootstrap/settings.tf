locals {
  settings = {
    nodes = {
      "k8s-home-prod-002.int.sajbox.net" = {
        name              = "k8s002"
        instance_id       = 1
        disko_main_device = "/dev/nvme0n1"
      }
    }
  }
}
