{ inputs, pkgs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  claude-code = llm.claude-code;

  # happy-coder не распознаёт nix-обёртку native-бинаря claude (ждёт cli.js или
  # node_modules/@anthropic-ai/claude-code рядом). Задаём HAPPY_CLAUDE_PATH только
  # для самого happy — он имеет приоритет над эвристикой поиска и не течёт в
  # глобальное окружение.
  happy-coder = pkgs.symlinkJoin {
    name = "happy-coder-wrapped";
    paths = [ llm.happy-coder ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in happy happy-mcp; do
        wrapProgram $out/bin/$bin \
          --set HAPPY_CLAUDE_PATH ${claude-code}/bin/claude
      done
    '';
  };
in
{
  home.packages = [
    claude-code
    happy-coder
  ];
}
