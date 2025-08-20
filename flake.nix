{
  description = "nexus-core nixos configuration";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    # nix
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    systems.url = "github:nix-systems/default-linux";
    hardware.url = "github:nixos/nixos-hardware";

    # disko
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-master,
    systems,
    ...
  } @ inputs: let
    inherit (self) outputs;
    inherit (nixpkgs) lib;

    # Define the unstable overlay
    overlay-unstable = final: prev: {
      unstable = import nixpkgs-unstable {
        inherit (prev) system;
        config.allowUnfree = true;
      };
      master = import nixpkgs-master {
        inherit (prev) system;
        config.allowUnfree = true;
      };
    };

    # Define pkgsFor with the overlay applied
    pkgsFor = lib.genAttrs (import systems) (
      system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.permittedInsecurePackages = [
            "electron-27.3.11"
          ];
          overlays = [overlay-unstable];
        }
    );

    # Helper function to create a NixOS system with overlaid pkgs
    mkSystem = hostname: system:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/${hostname}
          {
            # Ensure the system uses our overlaid pkgs
            nixpkgs.pkgs = pkgsFor.${system};
          }
        ];
        specialArgs = {
          inherit inputs outputs;
        };
      };

    # Helper function to create devShells for each system
    forEachSystem = f: lib.genAttrs (import systems) (system: f pkgsFor.${system});
  in {
    inherit lib;
    formatter = forEachSystem (pkgs: pkgs.alejandra);

    nixosConfigurations = {
      # desktop
      desktop = mkSystem "desktop" "x86_64-linux"; # Adjust system as needed
    };

    devShells = forEachSystem (pkgs: {
      default = pkgs.mkShell {
        NIX_CONFIG = "extra-experimental-features = nix-command flakes ca-derivations";
        buildInputs = with pkgs; [
          # Essential NixOS development tools
          git
          nil # Nix language server
          nh
          terraform
          terraform-ls
          terramate
          kubernetes-helm
          helm-ls
          kubectl
          istioctl
          k6
          jq
          gh
          fluxcd
          tree
          wget
          # Other useful tools for your NixOS configuration
          alejandra # Nix code formatter
          statix # Lints and suggestions for the Nix programming language
          cilium-cli
          openssl
        ];

        shellHook = ''
          echo "🚀 Welcome to the NexusCore development environment!"
        '';
      };
    });
  };
}
