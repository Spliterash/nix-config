{ inputs, ... }:
{
  home.stateVersion = "25.11";
  imports = [
    ./home/soft/furryfox.nix
    ./home/soft/vesktop.nix
    ./home/git.nix
    ./home/plasma.nix
  ];
  programs.fzf.enable = true;
  programs.bash.enable = true;
  programs.bash.shellAliases = {
    nn = "sudo true && nh os build ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";
    nr = "nixos-rebuild repl --flake ~/config";
    nrr = "nix repl --file ~/config/repl.nix";
  };
}
