{ inputs, pkgs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    pkgs.graphify
    llm.claude-code
    llm.codex
  ];
}
