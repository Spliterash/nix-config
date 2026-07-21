{ config, pkgs, ... }:
#? Ноутбук: NVIDIA laptop GPU. Если это гибридная (Optimus) конфигурация с
#? двумя GPU, на месте при установке потребуется добавить hardware.nvidia.prime
#? с bus id'ами устройств (lspci | grep -E "VGA|3D") — см.
#? https://wiki.nixos.org/wiki/Nvidia#Offloading_or_PRIME
{
  environment.systemPackages = [ pkgs.btop ];

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
