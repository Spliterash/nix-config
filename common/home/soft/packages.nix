{ pkgs, ... }:
{
  # Свал-очка
  home.packages = with pkgs; [
    bruno
    (callPackage ../../packages/sniffcraft.nix { })
    atlas
  ];
  programs.libreoffice.enable = true;
}
