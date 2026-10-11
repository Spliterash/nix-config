{ config, pkgs, ... }:
#? Ноутбук: AMD Renoir + NVIDIA GTX 1650 (Turing), гибридная конфигурация.
#? Встроенный экран на AMD, HDMI на NVIDIA; PCI-адреса проверены на ноутбуке.
#? NVIDIA используется через PRIME offload — см.
#? https://wiki.nixos.org/wiki/Nvidia#Offloading_or_PRIME
{
  environment.systemPackages = [ pkgs.btop ];

  boot.initrd.kernelModules = [ "amdgpu" ];

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    # На Turing RTD3 требует закрытого драйвера; используем его без GSP.
    open = false;
    gsp.enable = false;
    moduleParams.nvidia.NVreg_EnableGpuFirmware = 0;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    powerManagement = {
      enable = true;
      finegrained = true;
    };

    prime = {
      amdgpuBusId = "PCI:5:0:0";
      nvidiaBusId = "PCI:1:0:0";
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };
}
