provider "vault" {
  address = "http://localhost:8200"
  token   = "myroot"
}
locals {
  ipv4 = "192.168.10.102"
}
module "deploy" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  nixos_system_attr          = "../nix#nixosConfigurations.bootstrap.config.system.build.toplevel"
  nixos_partitioner_attr     = "../nix#nixosConfigurations.bootstrap.config.system.build.diskoScript"
  install_user               = "root"
  target_host                = local.ipv4
  target_user                = "root"
  instance_id                = 4
  nixos_generate_config_path = "../nix/hosts/k8s002/hardware-configuration.nix"

  debug_logging = true
}
