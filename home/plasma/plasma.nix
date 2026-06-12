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
    # Чёрная «заставка» по простою вместо отдельного скринсейвера (в Plasma 6 его убрали).
    # Официальный путь от мейнтейнера KDE: использовать локскрин как заставку и разрешить
    # разблокировку без пароля. См. https://discuss.kde.org/t/screensavers-and-plasma-6-wayland/8959
    kscreenlocker = {
      autoLock = true; # срабатывать по простою
      timeout = 1; # через 1 минуту
      passwordRequired = false; # снимать БЕЗ пароля (то самое «отключить блокировку»)
      lockOnResume = false; # и не спрашивать после выхода из сна
      appearance = {
        wallpaperPlainColor = "0,0,0"; # сплошной чёрный фон
        alwaysShowClock = false; # без часов — чистый чёрный
        showMediaControls = false; # без медиа-контролов
      };
    };

    # Монитор НЕ гасить (никакого DPMS) и не приглушать яркость — только чёрная заливка.
    powerdevil.AC = {
      turnOffDisplay.idleTimeout = "never";
      dimDisplay.enable = false;
      autoSuspend = {
        action = "sleep";
        idleTimeout = 3600;
      };
    };
    #! broken logout session.sessionRestore.restoreOpenApplicationsOnLogin = "whenSessionWasManuallySaved";
    session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";

    workspace = {
      # Dark by default. Applied at login via `plasma-apply-lookandfeel -a`
      # (appearance only, so it won't reset the custom panel/layout).
      lookAndFeel = "org.kde.breezedark.desktop";
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
      # Win+Space toggles the group (Windows 10/11 default; matches vladik's
      # config). No Alt in the combo, so apps never see a lone Alt → no menu
      # activation / focus loss, and a held Shift keeps capitalising after a switch.
      options = [ "grp:win_space_toggle" ];
      switchingPolicy = "global";
      # NumLock включён при старте сессии (kcminputrc [Keyboard] NumLock).
      # SDDM-настройка ниже отвечает только за экран входа; сессия Plasma при
      # старте применяет своё значение и без этого гасит нумлок после бута.
      numlockOnStartup = "on";
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
    shortcuts = {
      "plasmashell"."activate application launcher" = "";

      # Ctrl+Alt+T → WezTerm instead of the default terminal. Konsole's .desktop
      # ships X-KDE-Shortcuts=Ctrl+Alt+T, so that binding wins regardless of
      # TerminalApplication/TerminalService. Clear Konsole's _launch, then assign
      # the same keys to WezTerm's .desktop.
      "services/org.kde.konsole.desktop"."_launch" = "none";
      "services/org.wezfurlong.wezterm.desktop"."_launch" = "Ctrl+Alt+T";
    };

    configFile = {
      "spectaclerc"."General"."clipboardGroup" = "PostScreenshotCopyImage";
      "spectaclerc"."General"."launchAction" = "UseLastUsedCapturemode";
      "spectaclerc"."GuiConfig"."captureMode" = 0;
      "spectaclerc"."GuiConfig"."quitAfterSaveCopyExport" = true;
      "plasma_calendar_holiday_regions"."General"."selectedRegions" = "ru_ru";
    };
  };
}
