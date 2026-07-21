{ pkgs, ... }:
{
  # Java
  programs.java = {
    enable = true;
    package = pkgs.zulu25;
  };

  # Node.js
  environment.systemPackages = with pkgs; [
    nodejs_24
    bun

    # Python
    python313
    python313Packages.pip
    python313Packages.virtualenv
    uv
  ];
}
