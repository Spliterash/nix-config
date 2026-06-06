{
  #? nr --argstr configurationName "coolvm"
  configurationName ? "main",
}:
let
  flake = builtins.getFlake (toString ./.);
  nixos = flake.nixosConfigurations.${configurationName};
  inherit (nixos) config;
in
nixos
// {
  c = config;
  inherit flake;
  home = builtins.head (builtins.attrValues config.home-manager.users) // {
    # .options — полный набор home-опций из homeConfigurations.nixd (импортирует
    # весь home.nix, см. flake.nix). config-значения берём из реального main выше.
    options = flake.homeConfigurations.nixd.options;
  };
}
