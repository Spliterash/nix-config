{ config, pkgs, ... }:

{
  boot.extraModulePackages = [
    config.boot.kernelPackages.amneziawg
  ];

  boot.kernelModules = [ "amneziawg" ];

  environment.systemPackages = [
    pkgs.amneziawg-tools
  ];
}
