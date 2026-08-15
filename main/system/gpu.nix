{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    btop-rocm
  ];

  gpuScreenRecorder.monitor = "DP-1"; # основной 2560x1440, priority 1 в kscreen-doctor
}
