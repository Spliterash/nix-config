{ ... }:
{
  home.stateVersion = "26.05";

  imports = [
    ../../home/common.nix

    # Проги
    ../../home/soft/furryfox
    ../../home/soft/sourcegit.nix
    ../../home/soft/vesktop.nix
    ../../home/soft/freesm.nix
    ../../home/soft/packages.nix

    # ../../home/soft/ollama.nix
    ../../home/soft/media.nix

    ../../home/hardware/mouse.nix
  ];
}
