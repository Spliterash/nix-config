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
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      settings = import ./settings.nix;
      inherit (settings) username;
      pkgs = nixpkgs.legacyPackages.${system};

      mkHost =
        hostName:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
          }
          // settings;
          modules = [
            ./hosts/${hostName}/modules.nix
            ./nix.nix
            # Comma
            inputs.nix-index-database.nixosModules.default
            { programs.nix-index-database.comma.enable = true; }
            # HomeManaaer
            (
              { specialArgs, ... }:
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = specialArgs;
                home-manager.users.${username} = ./hosts/${hostName}/home.nix;
                home-manager.backupFileExtension = "backup";
              }
            )
            inputs.home-manager.nixosModules.home-manager
          ];
        };
    in
    {
      #? Приколюха чтобы сурсы флейков складывать в папку инпут, мб не нужно, потом уберу
      packages.${system}.flakeInputs = pkgs.linkFarm "flake-inputs" (
        nixpkgs.lib.mapAttrsToList (name: input: {
          inherit name;
          path = input.outPath;
        }) (builtins.removeAttrs inputs [ "self" ])
      );

      nixosConfigurations.main = mkHost "main";
      nixosConfigurations.laptop = mkHost "laptop";

      #? Залупа чтобы работал лангуаге сервер в хом менеджере
      homeConfigurations.nixd = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs system;
        }
        // settings;
        modules = [
          ./hosts/main/home.nix
          # home.nix не задаёт username/homeDirectory (в реальной системе их ставит
          # NixOS-интеграция home-manager). Для standalone-конфига они обязательны,
          # но на .options не влияют — поэтому значения фейковые.
          {
            home.username = "nixd";
            home.homeDirectory = "/nixd";
          }
        ];
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
