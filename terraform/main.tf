provider "vault" {
  address = "http://localhost:8200"
  token   = "myroot"
}
data "vault_kv_secret_v2" "bootstrap" {
  mount = "secret"
  name = "bootstrap"
}
locals {
  ipv4 = "192.168.10.102"
}
module "deploy" {
  source                 = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  nixos_system_attr      = "../nix#nixosConfigurations.k8s002.config.system.build.toplevel"
  nixos_partitioner_attr = "../nix#nixosConfigurations.k8s002.config.system.build.diskoScript"
  install_user           = "root"
  target_host            = local.ipv4
  target_user            = "s0010054j"
  instance_id            = 2
  nixos_generate_config_path = "../nix/hosts/k8s002/hardware-configuration.nix"
}
