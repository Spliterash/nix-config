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
      };
      FdoSecrets.Enabled = true;
      SSHAgent.Enabled = true;
    };
  };
  xdg.autostart.enable = true;

  # Уже имеющийся plasma-manager пишет изменяемый INI, без отдельного mutable-модуля.
  xdg.configFile."keepassxc/keepassxc.ini".enable = lib.mkForce false;
  programs.plasma.configFile = {
    "keepassxc/keepassxc.ini" = config.programs.keepassxc.settings;
    "kwalletrc" = {
      Wallet.Enabled = false;
      "org.freedesktop.secrets".apiEnabled = false;
    };
  };

  systemd.user.tmpfiles.rules = [ "d %h/Sync/KeePassXC 0700 - - -" ];
}
