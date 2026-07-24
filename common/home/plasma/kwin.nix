{ ... }:
{
  programs.plasma = {
    kwin.titlebarButtons.left = [
      # MSF
      "more-window-actions"
      #? M(N)SF "application-menu"
      "on-all-desktops"
      "keep-above-windows"
    ];

    configFile = {
      # Отключает primary selection: выделенный текст больше не вставляется средним кликом.
      "kwinrc"."Wayland"."EnablePrimarySelection" = false;

      # Буфер обмена (Klipper). История лежит в ~/.local/share/klipper/history3.sqlite.
      # KeepClipboardContents форсит сохранение истории между перезапусками (дефолт KDE
      # тоже true, но фиксируем явно — overrideConfig=false не трогает необъявленные ключи).
      "klipperrc"."General"."MaxClipItems" = 256; # дефолт 20, максимум 2048
      "klipperrc"."General"."KeepClipboardContents" = true;
    };
  };
}
