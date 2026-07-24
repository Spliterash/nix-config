{ ... }:
{
  home.stateVersion = "26.05";

  imports = [
    ../../common/home
    ./power.nix
  ];
}
