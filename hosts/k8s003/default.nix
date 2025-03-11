{...}: {
  imports = [
    ../common/global
    ../common/optional/rpi.nix

    ./hardware-configuration.nix
  ];

  networking = {
    hostName = "k8s-home-prod-003";
    useDHCP = true;
    firewall.enable = false;
    usePredictableInterfaceNames = false;
  };

  # Avoiding some heavy IO
  nix.settings.auto-optimise-store = false;

  system.stateVersion = "24.11";
}
