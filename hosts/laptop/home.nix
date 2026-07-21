{ ... }:
{
  home.stateVersion = "26.05";

  imports = [
    ../../home/common.nix
    ../../home/plasma/power-laptop.nix

    # Отключено по умолчанию — включить при необходимости на ноуте:
    # ../../home/soft/furryfox
    # ../../home/soft/sourcegit.nix
    # ../../home/soft/vesktop.nix
    # ../../home/soft/freesm.nix
    # ../../home/soft/packages.nix
    # ../../home/soft/media.nix
  ];
}
