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
    open = true;
    prime.offload.enable = false;
  };

  hardware.graphics.enable = true;
}
