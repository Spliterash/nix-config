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

    ./soft/jetbrains/idea.nix
    ./soft/vscode
    ./soft/wezterm
    ./soft/yazi
    ./soft/claude.nix
  ];
}
