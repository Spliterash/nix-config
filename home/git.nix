{ ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    extraConfig = {
      core.fileMode = false;
      core.autocrlf = "input";
    };
  };
}
