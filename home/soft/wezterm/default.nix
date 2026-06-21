{
  xdg.mimeApps.associations.added."application/x-shellscript" = [ "org.wezfurlong.wezterm.desktop" ];
  xdg.terminal-exec.settings.default = "org.wezfurlong.wezterm.desktop";
  programs.zsh.shellAliases = {
    wt = "wezterm start --cwd ./";
  };
  programs.wezterm = {
    enable = true;
    extraConfig = builtins.readFile ./wezterm.lua;
  };
  programs.plasma = {
    configFile = {
      "kdeglobals"."General"."TerminalApplication" = "wezterm";
      "kdeglobals"."General"."TerminalService" = "org.wezfurlong.wezterm.desktop";
    };
  };
}
