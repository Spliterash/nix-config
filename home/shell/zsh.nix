{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zsh-completions
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    autocd = true;
    history.size = 100000;
    # fzf-tab подключается отдельно в ./fzf.nix (programs.zsh.plugins).
    # Home Manager грузит плагины (order 900) после compinit (570) и до
    # syntax-highlighting (1200) — именно этот порядок и нужен fzf-tab.
    initContent = ''
      #! add from home config
      bindkey -e
    ''
    + builtins.readFile ./.zshrc;
  };
}
