{ ... }:
{
  imports = [
    ../../common/system
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./disk-config.nix
    ./gpu.nix
    # ./powersaving.nix
  ];

  #? ZFS requires networking.hostId to be set
  networking.hostId = "97199ad0";
  networking.hostName = "main"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

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
}
