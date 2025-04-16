{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    btop
    curl
    dig
    git
    vim
    zoxide
    mlocate
  ];
}
