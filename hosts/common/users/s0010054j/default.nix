{
  pkgs,
  config,
  ...
}: let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in {
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "s0010054j";

  programs.direnv.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [
    "root"
    "s0010054j"
  ];

  security.pam.services.sddm.enableKwallet = true;

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  virtualisation.docker.enable = true;
  programs.ssh.startAgent = true;
  programs.steam.enable = true;
  programs.zsh.enable = true;
  services.locate.enable = true;

  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  users.users.s0010054j = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = ifTheyExist [
      "wheel"
      "docker"
      "libvirtd"
    ];
    packages = with pkgs; [
      chromium
      devpod
      ghostty
      git
      librewolf-bin
      logseq
      obsidian
      legcord
      vim
      vlc
      wget
      unstable.zed-editor-fhs
      unstable.package-version-server
      neovim
      tmux
      oh-my-zsh
      ripgrep
    ];
  };
}
