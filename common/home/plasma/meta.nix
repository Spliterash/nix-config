{
  dock = [
    "org.kde.dolphin"
    "org.wezfurlong.wezterm"
    "firefox"
    # "microsoft-edge"
    # "brave"
    "code"
    "com.ayugram.desktop"
    # "discord"
    "vesktop"
  ];
  shortcuts = [
    {
      name = "Save replay";
      # SIGUSR1 только главному процессу: gsr-kms-server живёт в том же
      # cgroup и от этого сигнала просто умер бы.
      command = "systemctl --user kill --kill-whom=main --signal=SIGUSR1 gpu-screen-recorder.service";
      keys = "Ctrl+Num+0";
    }
  ];
}
