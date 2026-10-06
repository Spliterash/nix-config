{ config, lib, ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    signing = lib.mkIf config.programs.gpg.enable {
      format = "openpgp";
      key = config.programs.git.settings.user.email;
      signByDefault = true;
    };
    settings = {
      user.name = "Spliterash";
      user.email = "me@spliterash.ru";

      core.fileMode = false;
      core.autocrlf = "input";

      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };
}
