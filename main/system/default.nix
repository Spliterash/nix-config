{ ... }:
{
  imports = [
    ../../common/system
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./disk-config.nix
    ./gpu.nix
    ../../agent/host.nix
    # ./powersaving.nix
  ];
  networking.hostId = "97199ad0";
  networking.hostName = "main";
  system.stateVersion = "25.11";

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
