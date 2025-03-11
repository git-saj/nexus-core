{...}: {
  imports = [
    ../common/global
    ../common/optional/nvidia.nix
    ../common/optional/boot.nix

    ./hardware-configuration.nix
  ];

  networking = {
    hostName = "k8s-home-prod-002";
    useDHCP = true;
    firewall.enable = false;
    usePredictableInterfaceNames = false;
  };

  system.stateVersion = "24.11";
}
