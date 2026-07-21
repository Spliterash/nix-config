{ ... }:
let
  meta = import ./meta.nix;
in
{
  # ?! Если раскоментить импорт этого файла в default.nix, то слетают иконки после каждого едита
  programs.plasma.panels = [
    # Windows-like panel at the bottom
    {
      location = "bottom";
      floating = true;
      height = 44;
      screen = "all";
      widgets = [
        {
          kickoff.icon = "nix-snowflake";
        }
        {
          pager.general.showApplicationIconsOnWindowOutlines = true;
        }
        {
          iconTasks = {
            launchers = map (dockApp: "applications:${dockApp}.desktop") meta.dock;
            behavior.grouping.clickAction = "showTooltips";
            settings.General.wheelEnabled = "AdjustVolume";
          };
        }
        "org.kde.plasma.marginsseparator"
        {
          plasmusicToolbar = {
            panelIcon = {
              albumCover = {
                fallbackToIcon = true;
                useAsIcon = true;
                # radius = 8; # default
                radius = 25;
              };
            };
            songText = {
              # displayInSeparateLines = true;  # breaks buttons layout
              scrolling = {
                behavior = "scrollOnHover";
              };
            };
          };
        }
        "org.kde.plasma.volume"
        {
          systemTray = {
            icons.spacing = "small";
            items = {
              shown = [
                "org.kde.plasma.battery"
                "org.kde.plasma.brightness"
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.keyboardlayout"
              ];
              # org.kde.plasma.cameraindicator,    org.kde.plasma.devicenotifier
              # org.kde.plasma.manage-inputmethod, org.kde.plasma.notifications, org.kde.plasma.keyboardindicator
              hidden = [
                "org.kde.plasma.volume"
                "org.kde.kscreen"
                "org.kde.plasma.clipboard"
                "org.kde.plasma.mediacontroller"
                "org.kde.plasma.keyboardindicator"
              ];
            };
          };
        }
        {
          digitalClock = {
            date.position = "belowTime";
            calendar.plugins = [ "holidaysevents" ];
            calendar.showWeekNumbers = true;
          };
        }
        "org.kde.plasma.showdesktop"
      ];
    }
  ];
}
