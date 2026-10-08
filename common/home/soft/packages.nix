{ pkgs, ... }:
{
  # Свал-очка
  home.packages = with pkgs; [
    bruno
    (callPackage ../../packages/sniffcraft.nix { })
    (callPackage ../../packages/photocraft.nix { })
    atlas
  ];
  programs.libreoffice.enable = true;
}
