{ inputs, pkgs, ... }:
let
  withPlugins = inputs.nix-jetbrains-plugins.lib.buildIdeWithPlugins pkgs;

  #? Фикс всплывашек, убрать когда пофиксят
  idea = pkgs.jetbrains.idea.override {
    vmopts = "-Dawt.toolkit.name=XToolkit";
  };
in
{
  home.packages = [
    (withPlugins idea [
      # Translation — https://plugins.jetbrains.com/plugin/8579-translation
      "cn.yiiguxing.plugin.translate"
    ])
  ];
}
