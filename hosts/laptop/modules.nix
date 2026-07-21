{ ... }:
{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/gpu/nvidia.nix
  ];

  networking.hostId = "5f12b943";
  networking.hostName = "laptop";

  # Свежая установка — версия релиза на момент установки (см. комментарий
  # в hosts/main/modules.nix про то, зачем это поле фиксируется один раз).
  system.stateVersion = "26.05";
}
