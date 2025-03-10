{ pkgs, inputs, ... }:
{
  environment.systemPackages = [
    inputs.nix-gaming.packages.${pkgs.system}.star-citizen
  ];

  # https://github.com/starcitizen-lug/information-howtos/wiki
  # Avoids crashes
  boot.kernel.sysctl = {
    "vm.max_map_count" = 16777216;
    "fs.file-max" = 524288;
  };
}
