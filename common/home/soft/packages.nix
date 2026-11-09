{ pkgs, ... }:
{
  # Свал-очка
  home.packages = with pkgs; [
    bruno
    paseo.desktop
    (callPackage ../../packages/sniffcraft.nix { })
    (callPackage ../../packages/cockpit-tools.nix { })
    atlas
    photocraft
  ];
  programs.libreoffice.enable = true;
}
