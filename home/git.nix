{ ... }:
{
  programs.git = {
    enable = true;
    extraConfig = {
      core.fileMode = false;
    };
  };
}
