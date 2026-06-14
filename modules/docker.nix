{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    docker
  ];
  virtualisation.docker.enable = true;
  users.users.spliterash = {
    extraGroups = [
      "docker"
    ];
  };
}
