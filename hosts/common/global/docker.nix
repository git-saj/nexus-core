{pkgs, ...}: {
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_26;
    logDriver = "json-file";
    extraOptions = "--log-opt max-size=10m --log-opt max-file=3";
  };
}
