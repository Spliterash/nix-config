{ inputs, pkgs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    llm.claude-code
    llm.codex
    llm.openspec
    llm.openspecui
    llm.opencode
    llm.omp
    pkgs.bubblewrap
    # Чтобы не ломались плагины
    (llm.pi.override { useBun = false; })
  ];
}
