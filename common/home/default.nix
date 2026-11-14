{ pkgs, ... }:
{
  xdg.enable = true;
  xdg.autostart.enable = true;

  programs.gpg.enable = true;
  programs.zellij = {
    enable = true;
  };
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
  };

  imports = [
    # Методы
    ./mutable-json.nix

    # База
    ./cli.nix
    ./plasma
    ./sound
    ./syncthing.nix
    ./ssh.nix

    # Свалка
    ./soft/packages.nix
    ./soft/jetbrains/idea.nix
    ./soft/vscode
    ./soft/wezterm
    ./soft/furryfox
    ./soft/sourcegit.nix
    ./soft/keepassxc.nix
    ./soft/vesktop.nix
    ./soft/freesm.nix
    ./soft/donut.nix
    ./soft/media.nix
  ];
}
