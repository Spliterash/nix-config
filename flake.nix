{
  description = "NixOS from Scratch";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.main = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./configuration.nix
          ./nix.nix
          ./modules/java.nix
          ./modules/nix-ld.nix
          (
            { specialArgs, ... }:
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.users.spliterash = ./home.nix;
              home-manager.backupFileExtension = "backup";
            }
          )
          inputs.home-manager.nixosModules.home-manager
        ];

      };
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}
