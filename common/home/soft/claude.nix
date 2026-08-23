{ inputs, pkgs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    llm.claude-code
    llm.codex
    pkgs.lmstudio
    llm.opencode
    pkgs.docker-sbx
  ];
}
