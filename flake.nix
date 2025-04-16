{
  description = "nexus-core nixos configuration";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nix-gaming.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
  };

  inputs = {
    # nix
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default-linux";
    hardware.url = "github:nixos/nixos-hardware";

    # disko
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # deploy-rs
    deploy-rs.url = "github:serokell/deploy-rs";

    # rpi-nix
    rpi-nix.url = "github:nix-community/raspberry-pi-nix/v0.4.1";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    systems,
    deploy-rs,
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
      # bootstrap
      bootstrap = mkSystem "bootstrap" "x86_64-linux"; # Adjust system as needed
      # desktop
      desktop = mkSystem "desktop" "x86_64-linux"; # Adjust system as needed
      # k8s-home-prod-002
      k8s002 = mkSystem "k8s002" "x86_64-linux"; # Adjust system as needed
      # k8s-home-prod-003
      k8s003 = mkSystem "k8s003" "aarch64-linux"; # Adjust system as needed
    };

    deploy.nodes.k8s002 = {
      hostname = "k8s-home-prod-002.int.sajbox.net";
      fastConnection = true;
      profiles = {
        system = {
          sshUser = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.k8s002;
          user = "root";
        };
      };
    };
    deploy.nodes.k8s003 = {
      hostname = "k8s-home-prod-003.int.sajbox.net";
      fastConnection = true;
      profiles = {
        system = {
          sshUser = "root";
          path = deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.k8s003;
          user = "root";
        };
      };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    devShells = forEachSystem (pkgs: {
      default = pkgs.mkShell {
        NIX_CONFIG = "extra-experimental-features = nix-command flakes ca-derivations";
        buildInputs = with pkgs; [
          # Essential NixOS development tools
          git
          nil # Nix language server
          nh
          inputs.deploy-rs.defaultPackage.${system}
          terraform
          terraform-ls
          terramate
          kubernetes-helm
          helm-ls
          kubectl
          istioctl
          k6
          lens
          jq
          gh
          fluxcd
          tree
          # Other useful tools for your NixOS configuration
          alejandra # Nix code formatter
          statix # Lints and suggestions for the Nix programming language
        ];

        shellHook = ''
          echo "🚀 Welcome to the NexusCore development environment!"
        '';
      };
    });
  };
}
