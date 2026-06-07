{ ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      core.fileMode = false;
      core.autocrlf = "input";
    };
  };
}
