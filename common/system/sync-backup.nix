{ config, pkgs, username, ... }:
let
  home = config.users.users.${username}.home;
  passwordFile = "${home}/.config/restic/sync-password";
  rcloneConfigFile = "${home}/.config/rclone/rclone.conf";
in
{
  environment.systemPackages = [ pkgs.rclone ];

  services.restic.backups.sync = {
    user = username;
    repository = "rclone:gdrive:backups/sync/${config.networking.hostName}";
    inherit passwordFile rcloneConfigFile;
    initialize = true;
    paths = [ "." ];
    extraBackupArgs = [ "--skip-if-unchanged" ];
    pruneOpts = [ "--keep-last 20" ];
    rcloneOptions.drive-use-trash = false;
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };

  systemd.services.restic-backups-sync = {
    path = [ pkgs.rclone ];
    unitConfig.ConditionPathExists = [ passwordFile rcloneConfigFile ];
    serviceConfig.WorkingDirectory = "${home}/Sync";
  };
}
