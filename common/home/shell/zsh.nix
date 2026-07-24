{
  config,
  flakePath,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    zsh-completions
    bat
  ];
  xdg.configFile."shell/".source =
    config.lib.file.mkOutOfStoreSymlink "${flakePath}/common/home/shell/scripts";
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    autocd = true;
    history.size = 100000;

    initContent = ''
      #! add from home config
      bindkey -e

      #! Source interactive shell helpers after compinit so compdef is available.
      for file in "''${XDG_CONFIG_HOME:-$HOME/.config}"/shell/*.sh(N); do
        source "$file"
      done
    ''
    + builtins.readFile ./.zshrc;
  };
}
