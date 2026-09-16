{ inputs, pkgs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    inputs.codex-desktop-linux.homeManagerModules.default
    inputs.omp.homeManagerModules.default
  ];
  programs.omp = {
    enable = true;
    settings.startup.quiet = true;
  };
  home.packages = [
    llm.claude-code
    llm.codex
    pkgs.lmstudio
    llm.opencode
    pkgs.docker-sbx
  ];
  programs.codexDesktopLinux = {
    enable = true;
  };
}
