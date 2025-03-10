{
  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = ["kvm-amd"];
    };
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
      };
      efi.canTouchEfiVariables = true;
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/9e827a48-3807-4c33-9f97-210a40379036";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/6415-53E8";
    fsType = "vfat";
  };

  # 8GB swap
  swapDevices = [
    {
      device = "/swapfile";
      size = 8196;
    }
  ];
  # 32GB zram
  zramSwap = {
    enable = true;
    memoryMax = 32 * 1024 * 1024 * 1024;
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = true;
  hardware.nvidia = {
    open = true;
    powerManagement.enable = true;
    prime.offload.enable = false;
  };
}
