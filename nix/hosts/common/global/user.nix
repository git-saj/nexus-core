{ pkgs, ... }:
{
  users.user.s0010054j = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIf6QboK9ZCFTn7fmSywFWeg9gY620qvqG7g1xXKjoz1"
  };
  nix.settings.allowed-users = [ "s0010054j" ];
}
