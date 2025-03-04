{ lib, inputs, ... }: {
  imports = [
    inputs.rpi-nix.nixosModules.raspberry-pi
  ];

  raspberry-pi-nix.board = "bcm2711";

  boot.kernelParams = [ "cgroup_enable=memory" "cgroup_enable=cpuset" "cgroup_memory=1" ]; # enable cgroups

}
