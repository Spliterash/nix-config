{
  flakePath,
  hostname,
  username,
  ...
}:
{
  programs.gpu-screen-recorder.ui.enable = true;

  home-manager.users.${username} =
    { config, ... }:
    {
      xdg.configFile."gpu-screen-recorder/config_ui".source =
        config.lib.file.mkOutOfStoreSymlink "${flakePath}/${hostname}/home/gpu-screen-recorder.json";

      xdg.configFile."autostart/gpu-screen-recorder-ui.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=GPU Screen Recorder
        Exec=gsr-ui launch-daemon
      '';
    };
}
