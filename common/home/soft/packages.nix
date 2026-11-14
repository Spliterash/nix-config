{ inputs, pkgs, ... }:
{
  # Свал-очка
  home.packages = with pkgs; [
    bruno
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.orca
    (callPackage ../../packages/sniffcraft.nix { })
    (callPackage ../../packages/cockpit-tools.nix { })
    atlas
    (callPackage ../../packages/photocraft.nix { })
  ];
  programs.libreoffice.enable = true;
}
