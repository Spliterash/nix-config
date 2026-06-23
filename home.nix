{ inputs, pkgs, ... }:
{
  home.stateVersion = "26.05";
  xdg.enable = true;
  imports = [
    # Методы
    ./home/mutable-json.nix
    # База
    ./home/shell/aliases.nix
    ./home/shell/zsh.nix
    ./home/shell/fzf.nix

    ./home/git.nix
    ./home/plasma
    ./home/sound
    # Проги
    ./home/soft/furryfox
    ./home/soft/sourcegit.nix
    ./home/soft/vesktop.nix
    ./home/soft/jetbrains/idea.nix
    ./home/soft/freesm.nix
    ./home/soft/vscode
    ./home/soft/wezterm
    ./home/soft/bruno.nix

    # ./home/soft/ollama.nix
    ./home/soft/media.nix
    ./home/soft/yazi
  ];
}
