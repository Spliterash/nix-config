{ ... }:
{
  home.stateVersion = "26.05";

  imports = [
    ../../common/home

    # ./soft/ollama.nix
    ./mouse.nix
    ./power.nix
  ];
}
