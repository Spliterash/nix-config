{
  inputs,
  pkgs,
  specialArgs,
  ...
}:
{
  imports = [
    ./nix.nix
    ./dev-tools.nix
    ./nix-ld.nix
    # Comma
    inputs.nix-index-database.nixosModules.default
    # HomeManaaer
    inputs.home-manager.nixosModules.home-manager
  ];

  programs.nix-index-database.comma.enable = true;
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];
  environment.systemPackages = with pkgs; [
    git
    git-lfs
    jq
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = specialArgs;
  };
}
