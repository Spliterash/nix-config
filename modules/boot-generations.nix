{
  pkgs,
  config,
  inputs,
  ...
}:
{
  # Хеш коммита конфига в генерации (столбец Configuration Revision в
  # `nixos-rebuild list-generations`; также `nixos-version --configuration-revision`).
  # self.rev — чистый коммит (дерево закоммичено), dirtyRev — "<хеш>-dirty" при
  # незакоммиченных правках, иначе null (→ Unknown). На грязном дереве self.rev
  # отсутствует, поэтому без dirtyRev eval бы падал — отсюда трёхступенчатый фолбэк.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  # Bootloader.

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 15;
  boot.loader.efi.canTouchEfiVariables = true;

  # ? Этот блок написан клодом, а то мне чёта не нравится мусор в бутменю
  # Заголовки генераций → "[N] [хеш*] (YYYY-MM-DD HH:MM) сообщение". Штатный билдер
  # хардкодит формат и не даёт опции, поэтому переписываем title готовых записей
  # (version-строку не трогаем — по ней идёт сортировка, новые сверху). Хеш =
  # system.configurationRevision, читаем из самой генерации; * = грязное дерево;
  # текста коммита в метаданных флейка нет → git log по хешу из локального репо.
  # Старые генерации без rev → "[N] (дата)".
  #
  # Свежий билдер systemd-boot адресует записи по хешу содержимого: файлы теперь
  # называются nixos-<sha256>.conf, а не nixos-generation-<N>.conf — номера генерации
  # в имени больше нет. Поэтому glob по nixos-*.conf, а N берём из строки
  # "version Generation <N> ...", которую билдер пишет внутрь записи.
  boot.loader.systemd-boot.extraInstallCommands =
    let
      repo = config.programs.nh.flake; # локальный git-репо (с .git) для git log
    in
    ''
      for conf in ${config.boot.loader.efi.efiSysMountPoint}/loader/entries/nixos-*.conf; do
        [ -e "$conf" ] || continue   # glob ничего не нашёл → остался literal pattern
        gen=$(${pkgs.gnused}/bin/sed -n 's/^version Generation \([0-9]\+\).*/\1/p' "$conf")
        link="/nix/var/nix/profiles/system-$gen-link"
        [ -n "$gen" ] && [ -L "$link" ] || continue

        ts=$(${pkgs.coreutils}/bin/date -d "@$(${pkgs.coreutils}/bin/stat -c %Y "$link")" '+%Y-%m-%d %H:%M')
        rev=$("$link/sw/bin/nixos-version" --configuration-revision 2>/dev/null || true)

        if [ -n "$rev" ]; then
          short=''${rev%-dirty}; short=''${short:0:7}
          [ "$rev" = "''${rev%-dirty}" ] || short="$short*"   # * = -dirty
          msg=$(${pkgs.git}/bin/git -c safe.directory='*' -C "${repo}" log -1 --format=%s "''${rev%-dirty}" 2>/dev/null || true)
          title="[$gen] [$short] ($ts)''${msg:+ ''${msg:0:100}}"
        else
          title="[$gen] ($ts)"
        fi

        # ENVIRON[] берёт title как есть — спецсимволы коммита (| & \ %) не ломают замену.
        t="$title" ${pkgs.gawk}/bin/awk '/^title /{print "title " ENVIRON["t"]; next} 1' "$conf" \
          > "$conf.tmp" && ${pkgs.coreutils}/bin/mv -f "$conf.tmp" "$conf"
      done
    '';
}
