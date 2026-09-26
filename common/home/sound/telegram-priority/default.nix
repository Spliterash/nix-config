{ pkgs, lib, ... }:
{
  systemd.user.services.telegram-priority = {
    Unit = {
      Description = "Pause media while Telegram plays audio";
      After = [ "pipewire.service" ];
    };
    Service = {
      ExecStart = lib.getExe (
        pkgs.writeShellApplication {
          name = "telegram-priority";
          runtimeInputs = with pkgs; [
            pipewire
            jq
            playerctl
          ];
          text = builtins.readFile ./telegram-priority.sh;
        }
      );
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
