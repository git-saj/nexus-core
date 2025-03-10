{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.common-gpu-nvidia
  ];

  hardware.nvidia = {
    open = false;
    prime.offload.enable = false;
  };
}
