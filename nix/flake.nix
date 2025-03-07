{
  description = "nexus-core nixos configuration";

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

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      systems,
      deploy-rs,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib;

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
          overlays = [ overlay-unstable ];
        }
      );

      # Helper function to create a NixOS system with overlaid pkgs
      mkSystem =
        hostname: system:
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
    in
    {
      inherit lib;

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
    };
}
