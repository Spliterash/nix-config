{ config, lib, ... }:
{
  programs.keepassxc = {
    enable = true;
    autostart = true;
    settings = {
      General.ConfigVersion = 2;
      Browser = {
        Enabled = true;
        BestMatchOnly = true;
        AlwaysAllowAccess = true;
        AlwaysAllowUpdate = true;
        UpdateBinaryPath = false;
        Browser_AllowLocalhostWithPasskeys = true;
      };
      GUI = {
        AdvancedSettings = true;
        CheckForUpdates = false;
        ColorPasswords = true;
        CompactMode = true;
        MinimizeOnClose = true;
        MinimizeOnStartup = true;
        ShowTrayIcon = true;
      };
      Security = {
        LockDatabaseIdleSeconds = 3600;
        LockDatabaseScreenLock = false;
      };
      PasswordGenerator = {
        Length = 32;
        SpecialChars = false;
      };
      FdoSecrets.Enabled = true;
      SSHAgent.Enabled = true;
    };
  };
}
