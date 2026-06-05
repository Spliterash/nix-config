{ ... }:
{
  #? Sunshine — self-hosted хост для стриминга игр на Moonlight.
  #? Это системный модуль (а не home-manager пакет), т.к. сервису нужны:
  #? CAP_SYS_ADMIN для захвата экрана, hardware.uinput для виртуального
  #? ввода (мышь/клава/геймпад), udev-правила, avahi и открытые порты.
  #? Сам сервис поднимается как systemd.user.service (graphical-session).
  #? Веб-UI настройки: https://localhost:47990
  services.sunshine = {
    enable = true;
    openFirewall = true;
    #? KDE Plasma 6 на Wayland — захват экрана идёт через DRM/KMS,
    #? которому нужен CAP_SYS_ADMIN на бинаре sunshine.
    capSysAdmin = true;
    autoStart = true;
  };
}
