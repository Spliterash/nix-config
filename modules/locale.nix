{ pkgs, config, ... }:
#? comfort and rational settings for locales
{
  time.timeZone = "Europe/Moscow";

  # NTP-серверы для синхронизации времени (рабочие в России).
  # systemd-timesyncd включён по умолчанию. services.timesyncd.servers пишется
  # в `NTP=` (основной список); networking.timeServers ушёл бы только в
  # `FallbackNTP=` (резерв в последнюю очередь) — поэтому задаём именно servers.
  # vniiftri.ru — серверы Госслужбы времени (ВНИИФТРИ, Менделеево), stratum 1;
  # ru.pool.ntp.org — российская зона глобального пула NTP как запасной вариант.
  services.timesyncd.servers = [
    "ntp1.vniiftri.ru"
    "ntp2.vniiftri.ru"
    "ntp3.vniiftri.ru"
    "0.ru.pool.ntp.org"
    "1.ru.pool.ntp.org"
  ];

  i18n = {
    glibcLocales = (
      pkgs.callPackage ../packages/locales-iso.nix {
        locales = config.i18n.supportedLocales;
      }
    );
    extraLocaleSettings = {
      LC_COLLATE = "en_US.UTF-8"; # ? human readable ordering
      #! LC_CTYPE,LC_MEASUREMENT is skipped as unused
      #! LC_MESSAGES,LC_NAME is skipped as useless
      LC_MONETARY = "en_US.UTF-8"; # ? , as thousand separator
      LC_NUMERIC = "en_US.UTF-8"; # ? , as thousand separator
      LC_TIME = "ru_RU.UTF-8";
      #? я русский
      LC_ADDRESS = "ru_RU.UTF-8";
      LC_TELEPHONE = "ru_RU.UTF-8";
    };
  };
}
