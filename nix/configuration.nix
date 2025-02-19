{ modulesPath, lib, pkgs, sshPubKey, ... }:
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
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIf6QboK9ZCFTn7fmSywFWeg9gY620qvqG7g1xXKjoz1"
  ];

  system.stateVersion = "24.11";
}
