{ config, pkgs, ... }:
{
  home.packages = [
    (pkgs.sourcegit.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./sourcegit-metadata-only.patch ];
    }))
  ];
  mutableJson."${config.home.homeDirectory}/.config/SourceGit/preference.json".settings = {
    theme = "dark";
    nested.foo = "bar";
  };
}
