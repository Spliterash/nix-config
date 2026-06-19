# Настройки для `nixos-rebuild build-vm` — чтобы тестовая VM запускалась с
# 3D-ускорением через хостовую видеокарту, нормальным объёмом RAM/ядер и в
# целом годилась для интерактивной работы (Plasma 6).
#
# ВАЖНО: всё лежит под `virtualisation.vmVariant`, поэтому применяется ТОЛЬКО
# при сборке VM (`build-vm`) и никак не влияет на реальную систему при обычном
# `nixos-rebuild switch`. Опция определена модулем
# nixos/modules/virtualisation/build-vm.nix, который входит в базовый
# module-list, так что задавать её безопасно всегда.
#
# Хостовые fileSystems (btrfs-сабволы, NTFS /mnt/data) qemu-vm перетирает через
# mkVMOverride своими виртуальными монтированиями — VM получает чистый qcow2-root
# и не виснет на отсутствующих разделах.
{ username, ... }:
{
  virtualisation.vmVariant.virtualisation = {
    # Ресурсы. Дефолты (1 ядро / 1024 МиБ) для Plasma 6 непригодны.
    cores = 8; # из 12 ядер хоста
    memorySize = 12288; # МиБ = 12 ГиБ
    # qcow2 разрежен — реально на диске занимает по факту записанного, не 32 ГиБ.
    diskSize = 32768; # МиБ

    # Разрешение окна VM по умолчанию (KWin потом всё равно подхватывает динамически).
    resolution = {
      x = 1920;
      y = 1080;
    };

    qemu.options = [
      # --- 3D-ускорение (VirGL) ---
      # `-vga none` убирает неявный дефолтный std-VGA, иначе в госте окажется два
      # видеоадаптера. virtio-vga-gl сам VGA-совместим, поэтому ранняя консоль
      # загрузки тоже работает. Гостю достаточно штатной Mesa (драйвер virgl) и
      # модуля virtio_gpu — они уже есть в любой NixOS-системе.
      # `-display gtk,gl=on` — рендер через EGL на хостовой AMD-карте.
      # zoom-to-fit масштабирует кадр под размер окна.
      "-vga none"
      "-device virtio-vga-gl"
      "-display gtk,gl=on,zoom-to-fit=on"

      # --- Звук на хост ---
      # qemu_kvm в nixpkgs собран с pipewire-бэкендом; гость видит эмулируемую
      # HDA-карту, pipewire/pulse внутри VM маршрутизирует звук в неё, QEMU
      # пробрасывает его на хост.
      "-audiodev pipewire,id=snd0"
      "-device intel-hda"
      "-device hda-output,audiodev=snd0"
    ];
  };

  # Автологин в VM, чтобы не вводить пароль при каждом тестовом запуске.
  # Тоже только внутри vmVariant — реальную систему не трогает. Если нужно
  # тестировать именно экран входа SDDM — закомментировать этот блок.
  virtualisation.vmVariant.services.displayManager.autoLogin = {
    enable = true;
    user = username;
  };
}
