{
  pkgs ? import <nixpkgs> { },
  ...
}:
{
  default = pkgs.mkShell {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes ca-derivations";
    nativeBuildInputs = with pkgs; [
      # Essential NixOS development tools
      git
      nixpkgs-fmt
      nil # Nix language server
      nh
      deploy-rs
      terraform
      terraform-ls
      kubernetes-helm

      # Other useful tools for your NixOS configuration
      alejandra # Nix code formatter
      statix # Lints and suggestions for the Nix programming language
    ];

    shellHook = ''
      echo "🚀 Welcome to the NexusCore development environment!"
      echo "Available tools:"
      echo "  - git: Version control"
      echo "  - nixpkgs-fmt/alejandra: Nix code formatters"
      echo "  - nil: Nix language server"
      echo "  - deploy-rs: Deployment tool"
      echo "  - statix: Nix linter"
      echo ""
    '';
  };
}
