{ inputs, pkgs, ... }:
{
  home.stateVersion = "25.11";
  imports = [
    ./home/soft/furryfox.nix
    ./home/soft/vesktop.nix
    ./home/git.nix
    ./home/plasma.nix
  ];

  home.shellAliases = {
    nn = "sudo true && nh os switch ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";
    nr = "nixos-rebuild repl --flake ~/config";
    nrr = "nix repl --file ~/config/repl.nix";
  };

  home.packages = with pkgs; [ zsh-completions ];

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
