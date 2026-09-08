{ inputs, pkgs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.codex-desktop-linux.homeManagerModules.default ];
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
