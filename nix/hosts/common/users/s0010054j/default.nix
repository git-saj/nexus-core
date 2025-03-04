{
  pkgs,
  config,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
  unstablePkgs = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  });
in
{

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.xserver.xkb = {
    layout = "gb";
    variant = "";
  };

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "s0010054j";

  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [
    "root"
    "s0010054j"
  ];

  security.pam.services.sddm.enableKwallet = true;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-27.3.11"
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  virtualisation.docker.enable = true;
  programs.ssh.startAgent = true;

  users.mutableUsers = false;
  users.users.s0010054j = {
    isNormalUser = true;
    extraGroups = ifTheyExist [
      "wheel"
      "docker"
    ];
    packages = with pkgs; [
      chromium
      devpod
      ghostty
      git
      go
      gopls
      jq
      kubectl
      kubernetes-helm
      librewolf
      logseq
      nh
      nil
      nixfmt-rfc-style
      obsidian
      protonvpn-gui
      terraform
      terraform-ls
      vault
      vesktop
      vim
      wget
      zed-editor
      unstablePkgs.claude-code
      unstablePkgs.package-version-server
    ];
  };
}
