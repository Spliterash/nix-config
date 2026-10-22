{ inputs, pkgs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    inputs.codex-desktop-linux.homeManagerModules.default
  ];
  home.packages = [
    llm.opencode
    llm.omp
    llm.openspecui
    # Чтобы не ломались плагины
    (llm.pi.override { useBun = false; })
  ];
  programs.codexDesktopLinux = {
    enable = true;
  };
}
