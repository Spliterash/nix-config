{ ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = "Spliterash";
      user.email = "me@spliterash.ru";

      core.fileMode = false;
      core.autocrlf = "input";

      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };
}
