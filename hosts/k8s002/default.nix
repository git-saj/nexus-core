{pkgs, ...}: {
  imports = [
    ../common/global
    ../common/optional/nvidia.nix
    ../common/optional/boot.nix
    ../common/optional/disko.nix

    ./hardware-configuration.nix
  ];

  disko.devices.disk.main.device = "/dev/nvme0n1";

  networking = {
    hostName = "k8s-home-prod-002";
    useDHCP = true;
    firewall.enable = false;
    usePredictableInterfaceNames = false;
  };

  environment.systemPackages = with pkgs; [
    nodejs
    ffmpeg-full
    typescript
    cudatoolkit
  ];

  system.stateVersion = "24.11";
}
