{ inputs, pkgs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    llm.opencode
    llm.omp
    pkgs.bubblewrap
    pkgs.paseo.desktop
    llm.antigravity-cli
    llm.antigravity-hub
    # Чтобы не ломались плагины
    (llm.pi.override { useBun = false; })
  ];
}
