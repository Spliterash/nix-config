{inputs,...}:
{
  home.stateVersion = "25.11";
  imports = [
    ./home/soft/furryfox.nix
    ./home/soft/vesktop.nix
  ];
  programs.fzf.enable = true;
  programs.bash.enable = true;
}
