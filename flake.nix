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
          ./modules/gaming/steam.nix

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

      #? Отдельный home-manager-конфиг ТОЛЬКО ради .options для nixd (issue #705).
      #? Опции от модулей-инпутов (programs.plasma, programs.nixcord) добавляются
      #? через imports внутри home.nix, а main…getSubOptions [] их не видит (отдаёт
      #? лишь статический тип сабмодуля). Импортируем home.nix ЦЕЛИКОМ — набор опций
      #? всегда совпадает с реальным конфигом, перечислять модули руками не нужно.
      #? Не собирается, нужен только .options; .vscode/settings.json мерджит их к
      #? базовым (// nixd.options).
      homeConfigurations.nixd = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs system; };
        modules = [
          ./home.nix
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
