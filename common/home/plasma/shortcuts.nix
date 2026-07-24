{ lib, ... }:
let
  meta = import ./meta.nix;
  mkPlasmaBinds =
    shortcuts:
    builtins.listToAttrs (
      map (shortcut: {
        name = builtins.replaceStrings [ " " ] [ "-" ] shortcut.name;
        value = {
          name = shortcut.name;
          command = shortcut.command;
          key = builtins.replaceStrings [ "Mod" ] [ "Meta" ] shortcut.keys;
        };
      }) shortcuts
    );
in
{
  #? https://github.com/nix-community/plasma-manager
  #? https://nix-community.github.io/plasma-manager/options.xhtml
  programs.plasma = {
    hotkeys.commands = lib.attrsets.mergeAttrsList [
      (mkPlasmaBinds meta.shortcuts)
    ];

    shortcuts = {
      "plasmashell"."activate application launcher" = "Meta";

      # Ctrl+Alt+T → WezTerm instead of the default terminal. Konsole's .desktop
      # ships X-KDE-Shortcuts=Ctrl+Alt+T, so that binding wins regardless of
      # TerminalApplication/TerminalService. Clear Konsole's _launch, then assign
      # the same keys to WezTerm's .desktop.
      "services/org.kde.konsole.desktop"."_launch" = "none";
      "services/org.wezfurlong.wezterm.desktop"."_launch" = "Ctrl+Alt+T";
      "services/org.kde.plasma-systemmonitor.desktop"."_launch" = [
        "Ctrl+Shift+Esc"
      ];
      "services/org.kde.spectacle.desktop" = {
        "ActiveWindowScreenShot" = "Ctrl+Print";
        "CurrentMonitorScreenShot" = "";
        "FullScreenScreenShot" = "none";
        "OpenWithoutScreenshot" = "";
        "RecordRegion" = "Shift+Print";
        "RecordScreen" = "none";
        "RecordWindow" = "none";
        "RectangularRegionScreenShot" = "none";
        "WindowUnderCursorScreenShot" = "none";
        "_launch" = "Print";
      };
    };
  };
}
