{ inputs, pkgs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ./shell/zsh.nix
    ./shell/aliases.nix
    ./shell/fzf.nix
    ./git.nix
    ./soft/yazi
    ./dev-tools.nix
  ];

  home.packages = [
    llm.claude-code
    llm.codex
    llm.openspec
  ];
}
