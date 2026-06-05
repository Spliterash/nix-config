{ inputs, pkgs, ... }:
let
  #? IntelliJ IDEA — Community was discontinued by JetBrains, idea-oss is the
  #? open-source successor (idea-ultimate / idea also available).
  #? https://blog.jetbrains.com/idea/2025/07/intellij-idea-unified-distribution-plan/

  #? Plugins: nixpkgs no longer resolves jetbrains plugins by id (since 26.11),
  #? so we pull derivations from nix-jetbrains-plugins. The IDE version is
  #? auto-detected; find plugin ids at the bottom of a Marketplace page.
  #? https://github.com/theCapypara/nix-jetbrains-plugins
  withPlugins = inputs.nix-jetbrains-plugins.lib.buildIdeWithPlugins pkgs;
in
{
  home.packages = [
    (withPlugins pkgs.jetbrains.idea [
      # Translation — https://plugins.jetbrains.com/plugin/8579-translation
      "cn.yiiguxing.plugin.translate"
    ])
  ];
}
