{ ... }:
{
  imports = [
    ./shell/zsh.nix
    ./shell/aliases.nix
    ./shell/fzf.nix
    ./git.nix
    ./soft/yazi
    ./dev-tools.nix
    ./soft/llm.nix
  ];
}
