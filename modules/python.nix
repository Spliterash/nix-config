{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    python313
    python313Packages.pip
    python313Packages.virtualenv
    uv
  ];
}
