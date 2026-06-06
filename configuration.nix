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
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

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
  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:win_space_toggle";
    # ,grp:lalt_lshift_toggle
    # ,ctrl:nocaps
  };
  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.settings.General.Numlock = "on";
  services.desktopManager.plasma6.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.spliterash = {
    isNormalUser = true;
    description = "spliterash";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
      "nopasswdlogin" # беспарольная разблокировка экрана KDE (см. security.pam ниже)
    ];
    packages = with pkgs; [
      kdePackages.kate
      #  thunderbird
    ];
  };

  # Беспарольная разблокировка экрана KDE (домашняя машина — лишний пароль не нужен).
  # Разблокировка идёт через PAM-сервис `kde`; добавляем sufficient-правило ПЕРЕД pam_unix:
  # членам группы nopasswdlogin пароль не спрашивается. Безопасно — если правило не подойдёт,
  # PAM просто продолжит цепочку и спросит пароль, как раньше (залочиться невозможно).
  # Логин в SDDM и sudo это НЕ затрагивает (у них свои PAM-сервисы).
  users.groups.nopasswdlogin = { };
  security.pam.services.kde.rules.auth.nopasswd = {
    control = "sufficient";
    modulePath = "${pkgs.pam}/lib/security/pam_succeed_if.so";
    args = [
      "user"
      "ingroup"
      "nopasswdlogin"
    ];
    order = config.security.pam.services.kde.rules.auth.unix.order - 10;
  };

  programs.zsh.enable = true;
  environment.shells = with pkgs; [ zsh ];

  # Install firefox.
  programs.nh.enable = true;
  programs.nh.flake = "/home/spliterash/config";
  programs.kdeconnect.enable = true;
  # Workaround for kdeconnect-app SIGSEGV in QML AOT lookup on DBus property
  # TODO unstable
  environment.sessionVariables.QML_DISABLE_DISK_CACHE = "1";

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
    vscode
    ayugram-desktop
    discord
    nixd
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
