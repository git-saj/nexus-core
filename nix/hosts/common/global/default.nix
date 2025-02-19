# This file (and the global directory) holds config that i use on all hosts
{
  inputs,
  outputs,
  ...
}: {
  imports =
  # TODO: implement autoupdate with hydra?
    [
      ./boot.nix
      ./disko.nix
      ./locale.nix
      ./openssh.nix
      ./packages.nix
      ./podman.nix
      ./systemd-initrd.nix
      ./user.nix
      ./zsh.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  hardware.enableRedistributableFirmware = true;

  services.speechd.enable = false;
}
