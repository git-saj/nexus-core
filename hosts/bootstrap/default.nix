{terraform, ...}: {
  imports = [
    ../common/global
    ../common/optional/boot.nix
    ../common/optional/disko.nix

    ./hardware-configuration.nix
  ];

  disko.devices.disk.main.device = terraform.disko_main_device;

  networking = {
    # TODO: do i need to add domain or will dhcp handle this?
    hostName = terraform.hostname;
    useDHCP = true;
    usePredictableInterfaceNames = false;
  };

  system.stateVersion = "24.11";
}
