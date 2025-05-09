# This file (and the global directory) holds config that i use on all hosts
{
  inputs,
  outputs,
  ...
}: {
  imports =
    # TODO: implement autoupdate with hydra?
    [
      ./docker.nix
      ./locale.nix
      ./openssh.nix
      ./packages.nix
      ./user.nix
    ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  hardware.enableRedistributableFirmware = true;
}
