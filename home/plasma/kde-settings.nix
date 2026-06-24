{
  pkgs,
  inputs,
  ...
}:
#? non-specific KDE settings, used by KDE apps even without KDE itself
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
  ];
  home.packages = [
    pkgs.plasmusic-toolbar
  ];

  programs.plasma = {
    enable = true;
    overrideConfig = false;
    configFile = {
      "kdeglobals"."General"."TerminalApplication" = "wezterm";
      "kdeglobals"."General"."TerminalService" = "org.wezfurlong.wezterm.desktop";
      # "kdeglobals"."PreviewSettings"."EnableRemoteFolderThumbnail" = true;
      "kdeglobals"."PreviewSettings"."MaximumRemoteSize" = 1073741824; # 1 GiB

      #? kde file portal settings
      "kdeglobals"."KFileDialog Settings"."Show hidden files" = true;
      "dolphinrc"."General"."ShowFullPath" = true;
      "dolphinrc"."General"."BrowseThroughArchives" = true;
      # TODO: "dolphinrc"."UiSettings"."ColorScheme" = "";
      "dolphinrc"."UiSettings"."ColorScheme" = "BreezeDark";
      "dolphinrc"."DetailsMode"."PreviewSize" = 16;
    };
  };
}
