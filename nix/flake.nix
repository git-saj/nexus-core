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
  };

  outputs = {
    self,
    nixpkgs,
    systems,
    ...
  } @ inputs: let
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
  in {
    inherit lib;
    nixosConfigurations = {
      # # k8s-home-prod-001
      # k8s001 = nixpkgs.lib.nixosSystem {
      #   modules = [ ./hosts/k8s001 ];
      #   specialArgs = {
      #     inherit inputs outputs;
      #   };
      # };
      # k8s-home-prod-002
      k8s002 = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/k8s002 ];
        specialArgs = {
          inherit inputs outputs;
        };
      };
      # # k8s-home-prod-003
      # k8s003 = nixpkgs.lib.nixosSystem {
      #   modules = [ ./hosts/k8s003 ];
      #   specialArgs = {
      #     inherit inputs outputs;
      #   };
      # };
    };
  };
}
