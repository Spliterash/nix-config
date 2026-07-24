{ pkgs, ... }:
{
  # Свал-очка
  home.packages = with pkgs; [
    bruno
    (callPackage ../../packages/sniffcraft.nix { })
    atlas
  ];
}
