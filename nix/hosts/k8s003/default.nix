{ inputs, ... }: {
  imports = [
    ../common/global
    ../common/optional/rpi.nix

    ./hardware-configuration.nix
  ];

  networking = {
    # TODO: do i need to add domain or will dhcp handle this?
    hostName = "k8s-home-prod-003";
    useDHCP = true;
    firewall.enable = false;
  };

  # Avoiding some heavy IO
  nix.settings.auto-optimise-store = false;

  system.stateVersion = "24.11";
}
