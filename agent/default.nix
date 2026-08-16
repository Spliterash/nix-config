{
  lib,
  pkgs,
  modulesPath,
  inputs,
  username,
  system,
  flakePath,
  ...
}@allInputs:
let
  llm = inputs.llm-agents.packages.${system};
  net = import ./network.nix allInputs;
  #! ключ генерит хост при первом старте и отдаёт сюда шарой, поэтому в
  #! репозитории его нет; sshd со StrictModes требует совпадения uid с хостом
  sshShare = "/mnt/agent-ssh";
in
{
  imports = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
    inputs.home-manager.nixosModules.home-manager
    ../common/system/nix.nix
    ../common/system/dev-tools.nix
    ../common/system/nix-ld.nix
  ];

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.05";

  networking = {
    hostName = "agent";
    useDHCP = false;
    #! единственный NIC — предсказуемые имена только мешают
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = net.guest;
        inherit (net) prefixLength;
      }
    ];
    defaultGateway = {
      address = net.gateway;
      interface = "eth0";
    };
    #! резолвера на шлюзе нет, DNS перехватывает sing-box на хосте
    nameservers = [ "1.1.1.1" ];
    firewall.allowedTCPPorts = [ 22 ];
  };

  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];
  environment.variables.NIX_REMOTE = "daemon";

  environment.systemPackages = with pkgs; [
    ffmpeg
    git
    git-lfs
    jq
  ];

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    description = username;
    extraGroups = [
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    authorizedKeysFiles = lib.mkForce [ "${sshShare}/id_ed25519.pub" ];
  };

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };
  systemd.services.docker.unitConfig.RequiresMountsFor = "/var/lib/docker";

  #! билды уходят в хостовый демон через socat, свой демон только мешал бы
  systemd.services.nix-daemon.enable = false;
  systemd.sockets.nix-daemon.enable = false;

  #! сокет-активация, а не просто сервис: активация home-manager первым делом
  #! дёргает nix-build, и ей нужна гарантия, что сокет уже слушает, а не что
  #! процесс-прокси «запущен»
  systemd.tmpfiles.rules = [ "d /nix/var/nix/daemon-socket 0755 root root -" ];

  systemd.sockets.agent-nix-daemon = {
    description = "Socket of the host nix-daemon";
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = "/nix/var/nix/daemon-socket/socket";
      SocketMode = "0666";
    };
  };

  systemd.services.agent-nix-daemon = {
    description = "Forward the nix-daemon socket to the host";
    requires = [ "agent-nix-daemon.socket" ];
    wants = [ "network-online.target" ];
    after = [
      "agent-nix-daemon.socket"
      "network-online.target"
    ];
    serviceConfig.ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd ${net.gateway}:${toString net.nixDaemonPort}";
  };

  systemd.services."home-manager-${username}" = {
    wants = [
      "agent-nix-daemon.socket"
      "network-online.target"
    ];
    after = [
      "agent-nix-daemon.socket"
      "network-online.target"
    ];
  };

  virtualisation = {
    graphics = false;
    cores = 4;
    memorySize = 8192;
    diskSize = 4096;
    #! пересоздаётся на каждый старт в ExecStartPre agent-vm.service
    diskImage = "${net.stateDir}/root.qcow2";
    mountHostNixStore = true;
    writableStore = false;
    #! loose-кэш не видит пути, появившиеся в хостовом store после старта VM
    nixStore9pCache = "none";

    sharedDirectories = {
      agentssh = {
        source = "${net.stateDir}/ssh";
        target = sshShare;
        securityModel = "none";
      };
    }
    // lib.listToAttrs (
      lib.imap0 (i: m: {
        name = "m${toString i}";
        value = {
          source = m.host;
          target = m.guest;
          securityModel = "none";
        };
      }) net.mounts
    );

    fileSystems."/var/lib/docker" = {
      device = "/dev/disk/by-id/virtio-docker";
      fsType = "ext4";
      autoFormat = true;
    };

    qemu.networkingOptions = lib.mkForce [
      "-netdev tap,id=net0,ifname=tap-agent,script=no,downscript=no"
      "-device virtio-net-pci,netdev=net0"
    ];

    qemu.drives = [
      {
        name = "docker";
        file = "${net.stateDir}/docker.qcow2";
        driveExtraOpts.format = "qcow2";
        deviceExtraOpts.serial = "docker";
      }
    ];
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {
    inherit
      inputs
      username
      system
      flakePath
      ;
  };
  home-manager.users.${username} = {
    home.stateVersion = "26.05";
    imports = [
      ../common/home/shell/zsh.nix
      ../common/home/shell/fzf.nix
      ../common/home/git.nix
      ../common/home/soft/yazi
      ../common/home/dev-tools.nix
    ];
    #! в госте нет чекаута флейка, на который смотрит mkOutOfStoreSymlink
    xdg.configFile."shell/".source = lib.mkForce ../common/home/shell/scripts;
    home.packages = [
      llm.claude-code
      llm.codex
    ];
  };
}
