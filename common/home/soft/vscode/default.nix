{
  pkgs,
  config,
  flakePath,
  ...
}:
let
  vscodeConfigDir = "${flakePath}/common/home/soft/vscode";
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default.extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
    ];
  };

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${vscodeConfigDir}/settings.json";
  xdg.configFile."Code/User/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${vscodeConfigDir}/keybindings.json";
}
