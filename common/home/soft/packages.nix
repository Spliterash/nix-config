{ pkgs, ... }:
{
  # Свал-очка
  home.packages = with pkgs; [
    bruno
    paseo.desktop
    (callPackage ../../packages/sniffcraft.nix { })
    (callPackage ../../packages/cockpit-tools.nix { })
    atlas
    (callPackage ../../packages/photocraft.nix { })
  ];
  programs.libreoffice.enable = true;
}
