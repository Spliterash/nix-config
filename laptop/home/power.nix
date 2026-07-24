{ ... }:
#? Только laptop — импортится напрямую из laptop/home/default.nix, не через
#? common/home/plasma/default.nix. На main вместо этого main/home/power.nix
#? (чёрная заливка, монитор никогда не гасить).
{
  programs.plasma.powerdevil = {
    battery = {
      turnOffDisplay.idleTimeout = 60; # 1 минута
      autoSuspend = {
        action = "sleep";
        idleTimeout = 900; # 15 минут
      };
    };

    AC = {
      turnOffDisplay.idleTimeout = 60; # 1 минута
      autoSuspend = {
        action = "sleep";
        idleTimeout = 3600; # 1 час — от сети спит реже
      };
    };
  };
}
