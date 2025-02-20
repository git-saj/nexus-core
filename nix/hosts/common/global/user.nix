{ pkgs, ... }:
{
  users.users.root = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIf6QboK9ZCFTn7fmSywFWeg9gY620qvqG7g1xXKjoz1"
    ];
  };
  nix.settings.allowed-users = [ "root" "@wheel" ];
}
