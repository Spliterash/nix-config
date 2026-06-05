{ inputs, system, ... }:
{
  home.packages = [
    inputs.freesmlauncher.packages.${system}.freesmlauncher
  ];
}
