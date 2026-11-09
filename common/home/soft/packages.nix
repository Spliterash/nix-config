{ pkgs, ... }:
{
  # Свал-очка
  home.packages = with pkgs; [
    bruno
    (callPackage ../../packages/sniffcraft.nix { })
    (callPackage ../../packages/cockpit-tools.nix { })
    atlas
    photocraft
  ];
  programs.libreoffice.enable = true;
}
