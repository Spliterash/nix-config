{ lib, config,pkgs, ... }:
let
  defaultCloneDir = "/home/spliterash/projects";
in
{
  home.packages = with pkgs; [
    sourcegit
  ];
  mutableJson."${config.home.homeDirectory}/.config/SourceGit/preference.json".settings = {
    theme = "dark";
    nested.foo = "bar";
  };
}
