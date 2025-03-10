{inputs, ...}: {
  imports = [
    ../common/global
    ../common/optional/nvidia.nix
    ../common/optional/boot.nix
    ../common/optional/disko.nix

    ./hardware-configuration.nix
  ];

  disko.devices.disk.main.device = "/dev/nvme0n1";

  networking = {
    # TODO: do i need to add domain or will dhcp handle this?
    hostName = "k8s-home-prod-002";
    useDHCP = true;
    firewall.enable = false;
  };

  system.stateVersion = "24.11";
}
