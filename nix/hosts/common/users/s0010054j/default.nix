{
  pkgs,
  config,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [
    "root"
    "s0010054j"
  ];

  security.pam.services.sddm.enableKwallet = true;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  virtualisation.docker.enable = true;
  programs.ssh.startAgent = true;

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
      librewolf-bin
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
      vlc
      wget
      zed-editor
      unstable.claude-code
      unstable.package-version-server
    ];
  };
}
