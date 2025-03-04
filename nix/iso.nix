{ config, pkgs, ... }:
let
  vaultPubKey = pkgs.runCommand "vault-pubkey" {
   	buildInputs = [ pkgs.vault ];
   	VAULT_ADDR = builtins.getEnv "VAULT_ADDR";
   	VAULT_TOKEN = builtins.getEnv "VAULT_TOKEN";
  }

  ''
	vault login -method=token -no-store token=$VAULT_TOKEN
	vault kv get -field=ssh_pubkey secret/bootstrap > $out
  '';

in
{
  nixpkgs.config.allowUnfree = true;

  imports = [ <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> ];

  networking.useDHCP = true;

  services.openssh = {
    enable = true;
    authorizedKeysFiles = [ "/etc/ssh/authorized_keys" ];
    settings = {
      PermitRootLogin = "yes";
    };
  };

  environment.etc."ssh/authorized_keys" = {
    text = builtins.readFile vaultPubKey;
    mode = "0444";
  };

  system.stateVersion = "24.11";
}
