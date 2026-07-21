# ЗАГЛУШКА. На реальном железе перегенерировать через
# `nixos-generate-config --no-filesystems --dir /tmp/hwscan` (файловые системы
# задаёт disko через disk-config.nix, отдельно генерировать их не нужно), затем
# перенести сюда актуальные boot.initrd.availableKernelModules/kernelModules/
# extraModulePackages и любые hardware.*-опции, которые предложит генератор.
# Смотри hosts/main/hardware-configuration.nix как пример итогового вида.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
