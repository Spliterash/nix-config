{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  withPlugins = inputs.nix-jetbrains-plugins.lib.buildIdeWithPlugins pkgs;
  jetbrains = import ./crack { inherit pkgs lib; };

  idea = jetbrains.wrap "idea" (
    #? Фикс всплывашек, убрать когда пофиксят
    pkgs.jetbrains.idea.override {
      vmopts = "-Dawt.toolkit.name=XToolkit";
    }
  );
in
{
  home.packages = [
    (withPlugins idea [
      # Translation — https://plugins.jetbrains.com/plugin/8579-translation
      "cn.yiiguxing.plugin.translate"
    ])
  ];
}
