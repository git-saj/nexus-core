provider "vault" {
  address = "http://localhost:8200"
  token   = "myroot"
}
data "vault_kv_secret_v2" "bootstrap" {
  mount = "secret"
  name = "bootstrap"
}
locals {
  nixos_vars_file = "../nix/nixos-vars.json" # Path to the JSON file containing NixOS variables
  nixos_vars = {
    vault_addr = "http://172.26.0.10:8200"
    vault_token = "myroot"
  }
  ipv4 = "192.168.10.102"
}
resource "local_file" "nixos_vars" {
  content         = jsonencode(local.nixos_vars) # Converts variables to JSON
  filename        = local.nixos_vars_file        # Specifies the output file path
  file_permission = "600"

  # Automatically adds the generated file to Git
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "git add -f '${local.nixos_vars_file}'"
  }
}
module "deploy" {
  source                 = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  nixos_system_attr      = "../nix#nixosConfigurations.k3s.config.system.build.toplevel"
  nixos_partitioner_attr = "../nix#nixosConfigurations.k3s.config.system.build.diskoScript"

  target_host            = local.ipv4
  instance_id            = local.ipv4

  nixos_generate_config_path = "../nix/hardware-configuration.nix"
  nix_options = {
    sandbox = false
  }

  depends_on = [ local_file.nixos_vars ]
}
