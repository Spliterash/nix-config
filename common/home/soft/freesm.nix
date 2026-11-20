{ pkgs, ... }:
{
  home.packages = [
    (pkgs.callPackage ../../packages/freesmlauncher.nix { })
  ];
}
