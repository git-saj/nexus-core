{ pkgs, inputs, ... }:
{
  environment.systemPackages = [
    (inputs.nix-gaming.packages.${pkgs.system}.star-citizen.override {
      disableEac = false;
      useUmu = true;
      preCommands = ''
        export __GL_SHADER_DISK_CACHE=true
        export __GL_SHADER_DISK_CACHE_PATH="$WINEPREFIX/nvidiacache"
        export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=true
      '';
    })
  ];

  # https://github.com/starcitizen-lug/information-howtos/wiki
  # Avoids crashes
  boot.kernel.sysctl = {
    "vm.max_map_count" = 16777216;
    "fs.file-max" = 524288;
  };
}
