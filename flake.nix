{
  description = "NixOS from Scratch";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-jetbrains-plugins = {
      url = "github:nix-community/nix-jetbrains-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    freesmlauncher = {
      url = "github:FreesmTeam/FreesmLauncher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      #? Симлинк-ферма исходников всех флейк-инпутов — чтобы IDE могла по ним
      #? ходить (поиск, "Go to File", чтение исходников вроде buildIdeWithPlugins).
      #? Собрать рядом с проектом:  nix build .#flakeInputs -o inputs   (алиас nin)
      packages.${system}.flakeInputs = pkgs.linkFarm "flake-inputs" (
        nixpkgs.lib.mapAttrsToList (name: input: {
          inherit name;
          path = input.outPath;
        }) (builtins.removeAttrs inputs [ "self" ])
      );

      nixosConfigurations.main = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs system;
        };
        modules = [
          ./configuration.nix
          ./nix.nix
          ./modules/java.nix
          ./modules/nix-ld.nix
          ./modules/wine.nix
          ./modules/sunshine.nix
          ./modules/hardware/xbox.nix
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
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
