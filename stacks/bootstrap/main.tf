module "bootstrap" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"
  for_each = {
    for k, v in local.nodes : k => v
    if lookup(v.nixos_anywhere, "enable", false) == true
  }

  nixos_system_attr          = "../..#nixosConfigurations.bootstrap.config.system.build.toplevel"
  nixos_partitioner_attr     = "../..#nixosConfigurations.bootstrap.config.system.build.diskoScript"
  install_user               = "root"
  target_host                = each.key
  target_user                = "root"
  instance_id                = each.value.nixos_anywhere.instance_id
  nixos_generate_config_path = format("../../hosts/%s/hardware-configuration.nix", each.value.name)

  special_args = {
    terraform = {
      disko_main_device = each.value.nixos_anywhere.disko_main_device
    }
  }

}

locals {
  results = {
    for k, v in module.bootstrap : k => v.result.out
  }
}
