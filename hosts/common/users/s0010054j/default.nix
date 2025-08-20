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

  services.openvpn.servers = {
    prdeu = {
      config = ''config /home/s0010054j/openvpn/prdeu.ovpn '';
      autoStart = false;
      updateResolvConf = true;
    };
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
  programs.nix-ld.enable = true;

  security.pam.services.sddm.enableKwallet = true;

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  virtualisation.docker.enable = true;
  programs.ssh.startAgent = true;
  programs.steam.enable = true;
  services.locate.enable = true;

  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableBashCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
    };
    histSize = 100000;

    ohMyZsh = {
      enable = true;
      plugins = ["thefuck"];
    };
  };

  users.users.s0010054j = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = ifTheyExist [
      "wheel"
      "docker"
      "libvirtd"
    ];
    packages = with pkgs; [
      (azure-cli.withExtensions [azure-cli.extensions.aks-preview azure-cli.extensions.resource-graph])
      kubectl
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
      pre-commit
      master.zed-editor-fhs
      unstable.package-version-server
      neovim
      tmux
      ripgrep
      thefuck
      teamspeak6-client
      jq
      postgresql
      bruno
      openssl
    ];
  };
}
