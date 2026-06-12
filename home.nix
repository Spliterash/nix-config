{ inputs, pkgs, ... }:
{
  home.stateVersion = "25.11";
  imports = [
    ./home/mutable-json.nix
    ./home/soft/furryfox/furryfox.nix
    ./home/soft/vesktop.nix
    ./home/soft/idea.nix
    ./home/soft/freesm.nix
    ./home/soft/vscode/vscode.nix
    ./home/soft/wezterm/wezterm.nix

    ./home/git.nix
    ./home/soft/sourcegit.nix
    ./home/plasma/plasma.nix
    ./home/sound/sound.nix

    ./home/shell/aliases.nix
    ./home/shell/zsh.nix
    ./home/shell/fzf.nix
  ];
}
