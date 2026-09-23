{ inputs, pkgs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    inputs.codex-desktop-linux.homeManagerModules.default
  ];
  home.packages = [
    llm.claude-code
    llm.codex
    llm.opencode
    llm.omp
    # Чтобы не ломались плагины
    (llm.pi.override { useBun = false; })
  ];
  programs.codexDesktopLinux = {
    enable = true;
  };
}
