{ ... }:
#? Только main — импортится напрямую из main/home/default.nix, не через
#? common/home/plasma/default.nix. На ноуте вместо этого laptop/home/power.nix.
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

    # Монитор гасить через 15 минут простоя, яркость не приглушать — плюс чёрная заливка локскрина.
    powerdevil.AC = {
      turnOffDisplay.idleTimeout = 900; # 15 минут
      dimDisplay.enable = false;
      autoSuspend = {
        action = "shutDown";
        idleTimeout = 21600; # 6 часов
      };
    };
  };
}
