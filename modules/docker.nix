{ pkgs, username, ... }: {
  environment.systemPackages = with pkgs; [
    docker
  ];
  virtualisation.docker.enable = true;
  users.users.${username} = {
    extraGroups = [
      "docker"
    ];
  };
}
