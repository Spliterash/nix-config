{ ... }:
# Энергосбережение отключено целиком (десктоп: стабильность/латентность важнее
# пары ватт в простое). Повод — DisplayPort/HDMI-аудио на AMD-видеокарте
# периодически проглатывало ~100 мс из-за агрессивного управления питанием.
{
  # CPU всегда на полных частотах, без снижения.
  powerManagement.cpuFreqGovernor = "performance";

  # Отключаем PCIe ASPM (энергосбережение линий PCIe → всплески задержек)
  # и автозасыпание USB-устройств.
  boot.kernelParams = [
    "pcie_aspm=off"
    "usbcore.autosuspend=-1"
  ];

  # Не даём аудио-кодекам HDA засыпать (иначе провалы звука по DP/HDMI).
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=0
  '';

  # Отключаем runtime-PM для всех PCI-устройств (держим их «бодрыми»).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="on"
  '';
}
