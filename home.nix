{ inputs, pkgs, ... }:
{
  home.stateVersion = "25.11";
  imports = [
    ./home/mutable-json.nix
    ./home/soft/furryfox.nix
    ./home/soft/vesktop.nix
    ./home/soft/idea.nix
    ./home/soft/freesm.nix
    ./home/soft/vscode/vscode.nix
    ./home/soft/wezterm/wezterm.nix

    ./home/git.nix
    ./home/soft/sourcegit.nix
    ./home/plasma/plasma.nix
    ./home/sound.nix
  ];

  home.shellAliases = {
    nhs = "sudo true && nh os switch ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";
    nhb = "sudo true && nh os boot ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";
    nht = "sudo true && nh os test ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";

    nr = "nixos-rebuild repl --flake ~/config";
    nrr = "nix repl --file ~/config/repl.nix";
    # symlink-ферма исходников флейк-инпутов в ~/config/inputs (для навигации в IDE)
    nin = "nix build ~/config#flakeInputs -o ~/config/inputs";
  };

  home.packages = with pkgs; [
    zsh-completions
  ];

  programs.fzf.enable = true;
  programs.bash.enable = true;

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    autocd = true;
    history.size = 100000;
    plugins = with pkgs; [
      {
        name = "zsh-fzf-tab";
        src = zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];
  };
}
