{
  config,
  lib,
  pkgs,
  inputs,
  username,
  system,
  flakePath,
  ...
}@allInputs:
let
  llm = inputs.llm-agents.packages.${system};
  vm = import ./vm.nix allInputs;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../common/system/nix.nix
    ../common/system/dev-tools.nix
    ../common/system/nix-ld.nix
  ];

  system.stateVersion = "26.05";

  microvm = {
    hypervisor = "qemu";
    vcpu = 4;
    mem = 8192;

    vsock.cid = vm.vsockCid;
    vsock.ssh.enable = true;

    interfaces = [ ];
    qemu.extraArgs = [
      "-netdev"
      "tap,id=eth0,ifname=guest0,script=no,downscript=no"
      "-device"
      "virtio-net-pci,netdev=eth0,mac=02:00:00:00:42:42"
      # microvm.nix задаёт format=raw для QEMU; -set меняет его до открытия дисков.
      "-set"
      "drive.vda.format=qcow2"
      "-set"
      "drive.vdb.format=qcow2"
    ];

    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        cache = "always";
      }
      {
        proto = "virtiofs";
        tag = "avm-host";
        source = vm.hostDir;
        mountPoint = vm.hostDir;
        readOnly = true;
      }
      {
        proto = "virtiofs";
        tag = "avm-shares";
        source = vm.sharesDir;
        mountPoint = vm.sharesDir;
        posixAcl = false;
        #! virtiofsd работает от root: всё, что создаёт гость (в том числе его
        #! root), на хосте принадлежит пользователю, а устройства создать нельзя
        extraArgs = [
          "--translate-uid=squash-guest:0:1000:4294967295"
          "--translate-gid=squash-guest:0:100:4294967295"
          "--modcaps=-mknod"
        ];
      }
    ];

    preStart = lib.concatMapStringsSep "\n" (volume: ''
      if [ ! -e ${lib.escapeShellArg volume.image} ]; then
        (
          export PATH=${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.e2fsprogs
              config.microvm.qemu.package
            ]
          }:$PATH
          umask 022
          tmp=$(mktemp -d ${vm.disksDir}/.create-XXXXXX)
          trap 'rm -rf "$tmp"' EXIT
          truncate -s ${toString volume.size}M "$tmp/disk.raw"
          mkfs.ext4 -q "$tmp/disk.raw"
          qemu-img convert -f raw -O qcow2 "$tmp/disk.raw" "$tmp/disk.qcow2"
          mv "$tmp/disk.qcow2" ${lib.escapeShellArg volume.image}
        )
      fi
    '') config.microvm.volumes;

    volumes = [
      {
        image = "${vm.disksDir}/root.qcow2";
        imageType = "qcow2";
        autoCreate = false;
        mountPoint = "/";
        size = 8192;
      }
      {
        image = "${vm.disksDir}/docker.qcow2";
        imageType = "qcow2";
        autoCreate = false;
        mountPoint = "/var/lib/docker";
        size = 32768;
      }
    ];
  };

  networking.hostName = vm.name;
  networking.useDHCP = false;
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = vm.guest;
      prefixLength = 30;
    }
  ];
  networking.defaultGateway = {
    address = vm.gateway;
    interface = "eth0";
  };
  networking.nameservers = [ "1.1.1.1" ];

  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
  };
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
    #! слушает только vsock (sshd-vsock.socket от systemd-ssh-generator)
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    authorizedKeysFiles = lib.mkForce [ "${vm.hostDir}/authorized_keys" ];
  };

  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
  };

  #! своего nix-daemon нет (store read-only), сборки уходят в хостовый через vsock
  systemd.sockets.host-nix-daemon = {
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = "/nix/var/nix/daemon-socket/socket";
      SocketMode = "0666";
      Accept = true;
    };
  };
  systemd.services."host-nix-daemon@".serviceConfig = {
    ExecStart = "${lib.getExe pkgs.socat} STDIO VSOCK-CONNECT:2:${toString vm.nixDaemonPort}";
    StandardInput = "socket";
  };

  systemd.services."home-manager-${username}" = {
    wants = [ "host-nix-daemon.socket" ];
    after = [ "host-nix-daemon.socket" ];
  };

  #! список монтирований готовит хост (avm-prepare), здесь только bind на место
  systemd.services.avm-mounts = {
    wantedBy = [ "multi-user.target" ];
    after = [ "home-manager-${username}.service" ];
    unitConfig.RequiresMountsFor = [
      vm.hostDir
      vm.sharesDir
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [
      pkgs.jq
      pkgs.util-linux
    ];
    script = ''
      jq -r '.[]' ${vm.hostDir}/mounts.json |
        { i=0; while read -r guest; do
          source=${vm.sharesDir}/$i
          if [ -d "$source" ]; then
            mkdir -p "$guest"
          else
            mkdir -p "$(dirname "$guest")"
            [ -e "$guest" ] || touch "$guest"
          fi
          mount --bind "$source" "$guest"
          i=$((i + 1))
        done; }
    '';
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
      ../common/home/shell/aliases.nix
      ../common/home/shell/fzf.nix
      ../common/home/git.nix
      ../common/home/soft/yazi
      ../common/home/dev-tools.nix
    ];
    #! в госте нет чекаута флейка, на который смотрит mkOutOfStoreSymlink
    xdg.configFile."shell/".source = lib.mkForce ../common/home/shell/scripts;
    #! compaudit обходит все completion-каталоги в /nix/store, а он на общей FS
    programs.zsh.completionInit = "autoload -U compinit && compinit -C";
    home.packages = [
      llm.claude-code
      llm.codex
    ];
  };
}
