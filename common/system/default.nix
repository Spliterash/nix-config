{ pkgs, username, ... }:
{
  imports = [
    ./nix.nix
    ./impermanence.nix
    ./locale.nix
    ./desktop-environment.nix
    ./boot-generations.nix
    ./dev-tools.nix
    ./nix-ld.nix
    ./throne.nix
    ./docker.nix
    ./wine.nix
    ./sunshine.nix
    ./hardware/xbox.nix
    ./gaming/steam.nix
    ./vm.nix
  ];

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_6_18;

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
    hashedPassword = "$y$j9T$sDul5xTFeiGQyorzE4Hhs.$DAp3OxAIVl4u4pWA6FQxJ2B1.Ge57E985FICueLwZz9";
    isNormalUser = true;
    description = username;
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
  programs.nh.flake = "/home/${username}/config";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  xdg.mime.defaultApplications = {
    "text/plain" = [ "code.desktop" ];
  };
  documentation.doc.enable = false;

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
    libva-utils
    nixfmt
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
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
