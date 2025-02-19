{ inputs, ... }: {
  imports = [
    ./hardware-configuration.nix

    ../common/global
    ../common/optional/nvidia.nix
  ];

  disko.devices.disk.main.device = "/dev/nvme0n1";

  networking = {
    # TODO: do i need to add domain or will dhcp handle this?
    hostName = "k8s-home-prod-002";
    useDHCP = true;
  };

  system.stateVersion = "24.11";
}
