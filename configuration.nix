# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  pkgs,
  config,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

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
          msg=$(${pkgs.git}/bin/git -c safe.directory='*' -C "${repo}" log -1 --format=%s "''${rev%-dirty}" 2>/dev/null)
          title="[$gen] [$short] ($ts)''${msg:+ ''${msg:0:100}}"
        else
          title="[$gen] ($ts)"
        fi

        # ENVIRON[] берёт title как есть — спецсимволы коммита (| & \ %) не ломают замену.
        t="$title" ${pkgs.gawk}/bin/awk '/^title /{print "title " ENVIRON["t"]; next} 1' "$conf" \
          > "$conf.tmp" && ${pkgs.coreutils}/bin/mv -f "$conf.tmp" "$conf"
      done
    '';

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  networking.hostName = "main"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Moscow";
  # Windows dualboot хранит в RTC локальное время, а не UTC
  time.hardwareClockInLocalTime = true;

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

  # Select internationalisation properties.
  i18n.defaultLocale = "ru_RU.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = false;
  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.settings.General.Numlock = "on";
  services.desktopManager.plasma6.enable = true;

  # Автологин без экрана входа. SDDM сам пропускает выбор юзера и сразу грузит
  # единственную сессию (Plasma 6). В VM свой autoLogin внутри vmVariant
  # (modules/vm.nix) — он этот блок не отменяет, оба про одного юзера.
  services.displayManager.autoLogin = {
    enable = true;
    user = "spliterash";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Sound. Stolen from Владик
  security.rtkit.enable = true;
  services.pipewire.enable = true;
  services.pipewire.extraConfig.pipewire = {
    "10-fix-popping" = {
      #? https://ventureo.codeberg.page/source/sound.html#choppy-audio
      "context.properties" = {
        "default.clock.min-quantum" = 2048;
        "default.clock.quantum" = 4096;
        "default.clock.max-quantum" = 8192;
      };
    };
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.spliterash = {
    hashedPassword = "$y$j9T$sDul5xTFeiGQyorzE4Hhs.$DAp3OxAIVl4u4pWA6FQxJ2B1.Ge57E985FICueLwZz9";
    isNormalUser = true;
    description = "spliterash";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [
      kdePackages.kate
      #  thunderbird
    ];
  };

  programs.zsh.enable = true;
  environment.shells = with pkgs; [ zsh ];

  programs.nh.enable = true;
  programs.nh.flake = "/home/spliterash/config";

  programs.kdeconnect.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  xdg.mime.defaultApplications = {
    "text/plain" = [ "code.desktop" ];
  };
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
    git-lfs
    jq
    inxi
    libnotify # notify-send
    ayugram-desktop
    nixd
    sshfs
    claude-code
    nixfmt
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
