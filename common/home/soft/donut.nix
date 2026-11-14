{ inputs, pkgs, ... }:
let
  program = inputs.donutbrowser.apps.${pkgs.stdenv.hostPlatform.system}.release-start.program;
in
{
  home.packages = [ (builtins.dirOf (builtins.dirOf program)) ];
  xdg.dataFile."applications/donut.desktop".source = "${pkgs.makeDesktopItem {
    name = "donut";
    desktopName = "Donut Browser";
    genericName = "Web Browser";
    exec = "${program} %U";
    icon = "${inputs.donutbrowser}/assets/logo.png";
    categories = [ "Network" "WebBrowser" ];
  }}/share/applications/donut.desktop";
}
