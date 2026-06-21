{ username, ... }: {
  virtualisation.docker = {
    enable = true;
    storageDriver = "zfs";
  };

  users.users.${username} = {
    extraGroups = [
      "docker"
    ];
  };
}
