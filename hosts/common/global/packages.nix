{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    btop
    curl
    git
    vim
    zoxide
  ];
}
