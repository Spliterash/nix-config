{ ... }:
{
  programs.plasma = {
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
        action = "shutDown";
        idleTimeout = 10800;
      };
    };
  };
}
