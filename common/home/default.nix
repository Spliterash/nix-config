{ ... }:
{
  xdg.enable = true;

  imports = [
    # Методы
    ./mutable-json.nix

    # База
    ./shell/aliases.nix
    ./shell/zsh.nix
    ./shell/fzf.nix

    ./git.nix
    ./plasma
    ./sound
    ./dev-tools.nix

    # Свалка
    ./soft/packages.nix
    ./soft/jetbrains/idea.nix
    ./soft/vscode
    ./soft/wezterm
    ./soft/yazi
    ./soft/claude.nix
    ./soft/furryfox
    ./soft/sourcegit.nix
    ./soft/vesktop.nix
    ./soft/freesm.nix
    ./soft/media.nix
  ];
}
