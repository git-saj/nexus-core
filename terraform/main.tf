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

  nixos_system_attr      = "../nix#nixosConfigurations.k3s.config.system.build.toplevel"
  nixos_partitioner_attr = "../nix#nixosConfigurations.k3s.config.system.build.diskoScript"
  target_host            = local.ipv4
  instance_id            = local.ipv4
  nixos_generate_config_path = "../nix/hardware-configuration.nix"
}
