{ modulesPath, lib, pkgs, sshPubKey, ... }:
let
  nixosVars = builtins.fromJSON (builtins.readFile ./nixos-vars.json);

  vaultPubKey = pkgs.runCommand "vault-pubkey" {
   	buildInputs = [ pkgs.vault ];
   	VAULT_ADDR = nixosVars.vault_addr;
   	VAULT_TOKEN = nixosVars.vault_token;
  }

  ''
	vault login -method=token -no-store token=$VAULT_TOKEN
	vault kv get -field=ssh_pubkey secret/bootstrap > $out
  '';
in
{
  imports = [
    ./disk-config.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  disko.devices.disk.main.device = "/dev/nvme0n1";

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.vim
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    (builtins.readFile vaultPubKey)
  ];

  system.stateVersion = "24.11";
}
