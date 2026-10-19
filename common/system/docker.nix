{ config, pkgs, username, ... }: {
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  environment.systemPackages = [ pkgs.podman-compose pkgs.podman-desktop ];
  systemd.sockets.podman.enable = false;

  home-manager.users.${username} = {
    home.sessionVariables.DOCKER_HOST = "unix://\${XDG_RUNTIME_DIR}/podman/podman.sock";
    services.podman = {
      enable = true;
      package = config.virtualisation.podman.package;
      autoUpdate.enable = false;
      settings.containers = {
        engine.compose_providers = [ "${pkgs.podman-compose}/bin/podman-compose" ];
      };
    };
  };

  users.users.${username}.linger = true;

  fileSystems."/var/lib/docker".neededForBoot = true;
  environment.persistence."/var/lib/docker".users.${username}.directories = [
    {
      directory = ".local/share/containers";
      mode = "0700";
    }
  ];
}
