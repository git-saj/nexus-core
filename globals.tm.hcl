globals {
  # global terraform version used across all stacks (stacks can override this)
  terraform_version = ">= 1.9.0, < 2.0.0"

  # global provider versions used across all stacks (stacks can override these)
  provider_versions = {
    rke = "1.7.0"
  }

  nodes = {
    "k8s-home-prod-002.int.sajbox.net" = {
      name = "k8s002"
      roles = ["controlplane", "worker", "etcd"]
      nixos_anywhere = {
        enable            = true
        instance_id       = 1
        disko_main_device = "/dev/nvme0n1"
      }
    }
    "k8s-home-prod-003.int.sajbox.net" = {
      name = "k8s003"
      roles = ["controlplane", "etcd"]
      nixos_anywhere = {
        enable = false
      }
    }
  }
}
