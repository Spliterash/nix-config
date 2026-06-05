{ inputs, ... }:
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
  ];

  programs.plasma = {
    enable = true;

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
    };

    configFile = {
      "ksmserverrc"."General"."loginMode" = "emptySession";
      # Alt+Shift в alternative-слот (release-trigger), чтобы не угонять фокус
      # в меню приложений. См. https://discuss.kde.org/t/22698
      "kglobalshortcutsrc"."KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" =
        "none,Alt+Shift\tnone\tSwitch to Next Keyboard Layout";
    };
  };
  # Фигня чтобы shiftalt и altshift норм работали, а то заебало
  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-enable-mnemonics = 0;
    gtk4.extraConfig.gtk-enable-mnemonics = 0;
  };
}
