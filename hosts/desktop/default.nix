{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-gpu-nvidia

    ./hardware-configuration.nix

    ../common/global
    ../common/users/s0010054j

    ../common/optional/pipewire.nix
  ];

  environment.systemPackages = with pkgs; [
    hello
  ];

  networking = {
    hostName = "desktop";
    useDHCP = true;
  };

  hardware.graphics.enable = true;

  system.stateVersion = "25.05";
}
