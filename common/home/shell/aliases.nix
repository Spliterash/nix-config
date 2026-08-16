{ flakePath, lib, ... }: {
  home.shellAliases = {
    nhs = "sudo true && nh os switch ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";
    nhb = "sudo true && nh os boot ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";
    nht = "sudo true && nh os test ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";
    nhvm = "sudo true && nh os build-vm ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";

    nr = "nixos-rebuild repl --flake ~/config";
    nrr = "nix repl --file ~/config/repl.nix";
    # symlink-ферма исходников флейк-инпутов в ~/config/inputs (для навигации в IDE)
    nin = "nix build ~/config#flakeInputs -o ~/config/inputs";

    nix-shell = "nix-shell --run zsh";
    ns = "nix-shell -p";
    ncode = "code --reuse-window $(nix eval --offline --file '<nixpkgs>' path)/pkgs/top-level/all-packages.nix";

    nn = "nh os switch ${flakePath} --keep-going";

    grok = lib.concatStringsSep " " [
      "ANTHROPIC_DEFAULT_SONNET_MODEL=grok-4.6"
      "ANTHROPIC_DEFAULT_OPUS_MODEL=grok-4.6"
      "ANTHROPIC_DEFAULT_HAIKU_MODEL=grok-4.6"
      "ANTHROPIC_DEFAULT_FABLE_MODEL=grok-4.6"
      "ANTHROPIC_MODEL=grok-4.6"
      "CLAUDE_CODE_MAX_CONTEXT_TOKENS=500000"
      "claude"
    ];
  };
}
