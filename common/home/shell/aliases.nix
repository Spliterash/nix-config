{ flakePath, lib, ... }: {
  home.shellAliases = {
    nhs = "sudo true && nh os switch ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";
    nhb = "sudo true && nh os boot ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";
    nht = "sudo true && nh os test ~/config && notify-send 'System build success' && exec $SHELL || notify-send 'System build failed'";

    nr = "nixos-rebuild repl --flake ~/config";
    nrr = "nix repl --file ~/config/repl.nix";

    nix-shell = "nix-shell --run zsh";
    ns = "nix-shell -p";

    grok = lib.concatStringsSep " " [
      "ANTHROPIC_DEFAULT_SONNET_MODEL=grok-4.6"
      "ANTHROPIC_DEFAULT_OPUS_MODEL=grok-4.6"
      "ANTHROPIC_DEFAULT_HAIKU_MODEL=grok-4.6"
      "ANTHROPIC_DEFAULT_FABLE_MODEL=grok-4.6"
      "ANTHROPIC_MODEL=grok-4.6"
      "CLAUDE_CODE_MAX_CONTEXT_TOKENS=500000"
      "claude"
    ];
    deepseek = lib.concatStringsSep " " [
      "ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-flash"
      "ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro"
      "ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash"
      "ANTHROPIC_DEFAULT_FABLE_MODEL=deepseek-v4-pro"
      "ANTHROPIC_MODEL=deepseek-v4-flash"
      "CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000"
      "claude"
    ];
    gpt = lib.concatStringsSep " " [
      "ANTHROPIC_DEFAULT_HAIKU_MODEL=gpt-5.6-luna"
      "ANTHROPIC_DEFAULT_SONNET_MODEL=gpt-5.6-terra"
      "ANTHROPIC_DEFAULT_OPUS_MODEL=gpt-5.6-sol"
      "ANTHROPIC_DEFAULT_FABLE_MODEL=gpt-5.6-sol"
      "ANTHROPIC_MODEL=gpt-5.6-sol"
      "CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000"
      "claude"
    ];
  };
}
