{ config, lib, ... }:
{
  programs.keepassxc = {
    enable = true;
    autostart = true;
    settings = {
      General.ConfigVersion = 2;
      Browser = {
        Enabled = true;
        UpdateBinaryPath = false;
      };
      GUI = {
        CheckForUpdates = false;
        MinimizeOnClose = true;
        MinimizeOnStartup = true;
        ShowTrayIcon = true;
        AlwaysAllowAccess = true;
        AlwaysAllowUpdate = true;
        Browser_AllowLocalhostWithPasskeys = true;
      };
      Security = {
        LockDatabaseIdleSeconds=3600;
      };
      FdoSecrets.Enabled = true;
      SSHAgent.Enabled = true;
    };
  };
}
