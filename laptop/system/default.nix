{ ... }:
{
  imports = [
    ../../common/system
    ./hardware-configuration.nix
    ./disk-config.nix
    ./gpu.nix
  ];

  networking.hostId = "5f12b943";
  networking.hostName = "laptop";

  # Свежая установка — версия релиза на момент установки (см. комментарий
  # в main/system/default.nix про то, зачем это поле фиксируется один раз).
  system.stateVersion = "26.05";
}
