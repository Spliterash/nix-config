{
  lib,
  pkgs,
  config,
  ...
}:
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
  imports = [
    ./kde-settings.nix
  ];

  #? https://github.com/nix-community/plasma-manager
  #? https://nix-community.github.io/plasma-manager/options.xhtml
  programs.plasma = {
    hotkeys.commands = lib.attrsets.mergeAttrsList [
      (mkPlasmaBinds meta.shortcuts)
    ];
    kscreenlocker.timeout = 15;
    #! broken logout session.sessionRestore.restoreOpenApplicationsOnLogin = "whenSessionWasManuallySaved";
    session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";

    workspace = {

      tooltipDelay = 500;
    };

    # Keyboard layouts + switching handled at the XKB layer (Plasma's kxkbrc).
    # On Wayland this is the reliable mechanism; the KGlobalAccel "Switch to Next
    # Keyboard Layout" shortcut below is disabled because a modifier-only bind
    # (Shift+Alt) grabs Alt — stealing menubar focus — and eats a held Shift after
    # a switch, so you can't keep Shift down to type capitals.
    input.keyboard = {
      layouts = [
        { layout = "us"; }
        { layout = "ru"; }
      ];
      # Left Alt + Left Shift toggles the group. Handled natively by libxkbcommon,
      # so the held Shift keeps capitalising and Alt isn't globally grabbed.
      options = [ "grp:lalt_lshift_toggle" ];
      switchingPolicy = "global";
    };

    # Mouse settings captured from kcminputrc. vendorId/productId are hex (decoded
    # to the decimal Libinput section path); name must match the device exactly,
    # trailing space included, or Plasma won't apply it to the device.
    input.mice = [
      {
        name = "COMPANY  USB Device ";
        vendorId = "09DA";
        productId = "50CA";
        acceleration = 0.2; # PointerAcceleration=0.200
        accelerationProfile = "none"; # PointerAccelerationProfile=1
      }
    ];
    kwin.titlebarButtons.left = [
      # MSF
      "more-window-actions"
      #? M(N)SF "application-menu"
      "on-all-desktops"
      "keep-above-windows"
    ];

    panels = [
      # Windows-like panel at the bottom
      {
        location = "bottom";
        floating = true;
        height = 44;
        # screen = 0;
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
          {
            systemMonitor = {
              title = "RAM Usage";
              displayStyle = "org.kde.ksysguard.linechart";
              sensors = [
                {
                  name = "memory/physical/usedPercent";
                  color = "0,255,0";
                  label = "RAM %";
                }
                {
                  name = "cpu/all/usage";
                  color = "255,0,0";
                  label = "CPU %";
                }
              ];
              totalSensors = [
                "memory/physical/used"
                "memory/physical/usedPercent"
              ];
              textOnlySensors = [
                "memory/physical/used"
                "memory/physical/total"
                "cpu/all/coreCount"
              ];
            };
          }
          {
            systemTray = {
              icons.spacing = "small";
              items = {
                shown = [
                  "org.kde.plasma.volume"
                  "org.kde.plasma.battery"
                  "org.kde.plasma.brightness"
                  "org.kde.plasma.bluetooth"
                  "org.kde.plasma.networkmanagement"
                  "org.kde.plasma.keyboardlayout"
                ];
                # org.kde.plasma.cameraindicator,    org.kde.plasma.devicenotifier
                # org.kde.plasma.manage-inputmethod, org.kde.plasma.notifications, org.kde.plasma.keyboardindicator
                hidden = [
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
              date.format = "isoDate";
              time.showSeconds = "always";
              calendar.showWeekNumbers = true;
            };
          }
          "org.kde.plasma.showdesktop"
        ];
      }
    ];

    shortcuts = {
      # Disabled ([ ] writes `none`): layout switching is done via the XKB toggle
      # in input.keyboard above, not via this modifier-only global shortcut.
      "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = [ ];
      "plasmashell" = {
        "activate application launcher" = "Meta";
      };
    };

    configFile = {
      "spectaclerc"."General"."clipboardGroup" = "PostScreenshotCopyImage";
      "spectaclerc"."General"."launchAction" = "UseLastUsedCapturemode";
      "spectaclerc"."GuiConfig"."captureMode" = 0;
      "spectaclerc"."GuiConfig"."quitAfterSaveCopyExport" = true;
    };
  };
  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-enable-mnemonics = 0;
    gtk4.extraConfig.gtk-enable-mnemonics = 0;
  };
}
