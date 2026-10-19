{ username, ... }: {
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  users.users.${username}.linger = true;

  fileSystems."/var/lib/docker".neededForBoot = true;
  environment.persistence."/var/lib/docker".users.${username}.directories = [
    {
      directory = ".local/share/docker";
      mode = "0700";
    }
  ];
}
