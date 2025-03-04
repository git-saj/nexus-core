{
  description = "nexus-core nixos configuration";

  inputs = {
    # nix
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
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
      systems,
      deploy-rs,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib;
      forEachSystem = f: lib.genAttrs (import systems) (system: f pkgsFor.${system});
      pkgsFor = lib.genAttrs (import systems) (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );
    in
    {
      inherit lib;
      nixosConfigurations = {
        # # k8s-home-prod-001
        # k8s001 = nixpkgs.lib.nixosSystem {
        #   modules = [ ./hosts/k8s001 ];
        #   specialArgs = {
        #     inherit inputs outputs;
        #   };
        # };
        # bootstrap
        bootstrap = nixpkgs.lib.nixosSystem {
          modules = [ ./hosts/bootstrap ];
          specialArgs = {
            inherit inputs outputs;
          };
        };
        # desktop
        desktop = nixpkgs.lib.nixosSystem {
          modules = [ ./hosts/desktop ];
          specialArgs = {
            inherit inputs outputs;
          };
        };
        # k8s-home-prod-002
        k8s002 = nixpkgs.lib.nixosSystem {
          modules = [ ./hosts/k8s002 ];
          specialArgs = {
            inherit inputs outputs;
          };
        };
        # k8s-home-prod-003
        k8s003 = nixpkgs.lib.nixosSystem {
          modules = [ ./hosts/k8s003 ];
          specialArgs = {
            inherit inputs outputs;
          };
        };
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
