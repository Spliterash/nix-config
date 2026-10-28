{ pkgs, lib, username, ... }:
{
  imports = [
    ./cli.nix
    ./impermanence.nix
    ./locale.nix
    ./desktop-environment.nix
    ./boot-generations.nix
    ./throne.nix
    ./docker.nix
    ./wine.nix
    ./sunshine.nix
    ./hardware/devices.nix
    ./hardware/xbox.nix
    ./gaming/steam.nix
    ./vm.nix
    ./amneziawg.nix
    ./gpu-screen-recorder.nix
  ];

  # Use the latest kernel branch supported by ZFS 2.4 (7.2 is not LTS).
  boot.kernelPackages = pkgs.linuxPackages_7_2;

  # Enable networking
  networking.networkmanager.enable = true;

  # Sound. Stolen from Владик
  security.rtkit.enable = true;
  services.pipewire.enable = true;

  services.zfs.autoScrub.enable = true;
  services.zfs.autoSnapshot.enable = true; # ! да, я включил снапшоты, саси (они бесплатные)

  # Windows dualboot хранит в RTC локальное время, а не UTC
  time.hardwareClockInLocalTime = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${username} = {
    # Initial password only, never resets existing accounts; SSH stays key-only.
    initialPassword = "0";
    isNormalUser = true;
    # Bootstrap key so fresh laptop is reachable without synced ~/.ssh.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHhPmnp+l2jntPqGQQLmsMD3vVSjNNiZiXg57yI9Ya/K spliterash@main"
    ];
    description = username;
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  programs.nh.enable = true;
  programs.nh.flake = "/home/${username}/config";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  xdg.mime.defaultApplications = lib.genAttrs [
    "text/*"
    "application/json"
    "application/json5"
    "application/*+json"
    "application/yaml"
    "application/*+yaml"
    "application/toml"
    "application/xml"
    "application/xml-dtd"
    "application/xml-external-parsed-entity"
    "application/xsd"
    "application/xslt+xml"
    "application/sql"
    "application/javascript"
    "application/ecmascript"
    "application/typescript"
    "application/x-shellscript"
    "application/x-fishscript"
    "application/x-nuscript"
    "application/x-powershell"
    "application/x-perl"
    "application/x-php"
    "application/x-ruby"
    "application/x-zerosize"
  ] (_: [ "code.desktop" ]);
  documentation.doc.enable = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    inxi
    libnotify # notify-send
    ayugram-desktop
    nixd
    sshfs
    libva-utils
    nixfmt
    unrar
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
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
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      AllowUsers = [ username ];
      AuthenticationMethods = "publickey";
      PubkeyAuthentication = true;
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
