{ pkgs, ... }:
{
  xdg.enable = true;

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

    # Свалка
    ./soft/packages.nix
    ./soft/jetbrains/idea.nix
    ./soft/vscode
    ./soft/wezterm
    ./soft/llm.nix
    ./soft/furryfox
    ./soft/sourcegit.nix
    ./soft/vesktop.nix
    ./soft/freesm.nix
    ./soft/media.nix
  ];
}
