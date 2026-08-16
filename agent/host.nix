{
  lib,
  pkgs,
  self,
  username,
  ...
}:
let
  net = import ./network.nix;
  vm = self.nixosConfigurations.agent.config.system.build.vm;

  tap = "tap-agent";
  tun = "sb-agent";
  sshHost = "agent";

  runDir = "${net.stateDir}/run";
  qmpSocket = "${runDir}/qmp.sock";
  sshKey = "${net.stateDir}/ssh/id_ed25519";
  dockerImage = "${net.stateDir}/docker.qcow2";

  avm = pkgs.callPackage ./avm.nix {
    inherit sshHost;
    unit = "agent-vm.service";
  };

  #! _secret подставляется root'ом в ExecStartPre sing-box, quote=false —
  #! содержимое файла парсится как JSON, а не как строка.
  proxyOutbound =
    if lib.isAttrs net.socks5 then
      {
        _secret = net.socks5.file;
        quote = false;
      }
    else
      {
        type = "socks";
        tag = "proxy";
        server = lib.head (lib.splitString ":" net.socks5);
        server_port = lib.toInt (lib.last (lib.splitString ":" net.socks5));
      };

  nftRules = pkgs.writeText "agent-vm.nft" ''
    table inet agent-vm
    delete table inet agent-vm
    table inet agent-vm {
      chain forward {
        type filter hook forward priority filter; policy accept;
        iifname "${tap}" oifname != "${tun}" counter drop
      }
    }
  '';
in
{
  boot.kernel.sysctl."net.ipv4.ip_forward" = true;
  networking.networkmanager.unmanaged = [ "interface-name:${tap}" ];

  #! auto_redirect делает трафик гостя локальным (DNAT на свой порт), так что
  #! он упирается в INPUT хоста. Порт sing-box выбирает случайно на каждый
  #! старт, перечислить нельзя. На FORWARD не влияет — выход наружу по-прежнему
  #! режет наше правило ниже.
  networking.firewall.trustedInterfaces = [ tap ];
  environment.systemPackages = [ avm ];

  #! чтобы avm start/stop не спрашивал пароль; правило только про этот юнит
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "agent-vm.service" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  programs.ssh.extraConfig = ''
    Host ${sshHost}
      HostName ${net.guest}
      User ${username}
      IdentityFile ${sshKey}
      IdentitiesOnly yes
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
      LogLevel ERROR
  '';

  services.sing-box = {
    enable = true;
    settings = {
      log.level = "info";
      dns = {
        servers = [
          {
            type = "udp";
            tag = "local";
            server = "1.1.1.1";
          }
        ];
        strategy = "ipv4_only";
      };
      inbounds = [
        {
          type = "tun";
          tag = "tun-in";
          interface_name = tun;
          address = [ "10.255.254.1/30" ];
          mtu = 1500;
          auto_route = true;
          auto_redirect = true;
          strict_route = false;
          stack = "system";
          #! единственное, что удерживает sing-box от перехвата трафика хоста
          include_interface = [ tap ];
        }
      ];
      outbounds = [
        {
          type = "direct";
          tag = "direct";
        }
        proxyOutbound
      ];
      route = {
        default_domain_resolver = "local";
        auto_detect_interface = true;
        final = "direct";
        rules = [
          { action = "sniff"; }
          {
            protocol = "dns";
            action = "hijack-dns";
          }
        ]
        ++ lib.optional (net.proxy != [ ]) {
          domain_suffix = map (lib.removePrefix "*.") net.proxy;
          outbound = "proxy";
        };
      };
    };
  };

  systemd.services.sing-box = {
    wantedBy = lib.mkForce [ ];
    partOf = [ "agent-vm.service" ];
    requires = [ "agent-vm-net.service" ];
    after = [ "agent-vm-net.service" ];
  };

  systemd.services.agent-vm-net = {
    description = "tap link and forward lock for the agent VM";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [
      pkgs.iproute2
      pkgs.nftables
    ];
    script = ''
      ip link delete ${tap} 2>/dev/null || true
      ip tuntap add dev ${tap} mode tap user ${username}
      ip addr add ${net.gateway}/${toString net.prefixLength} dev ${tap}
      ip link set ${tap} up
      nft -f ${nftRules}
    '';
    preStop = ''
      nft delete table inet agent-vm 2>/dev/null || true
      ip link delete ${tap} 2>/dev/null || true
    '';
  };

  systemd.services.agent-nix-daemon = {
    description = "host nix-daemon socket for the agent VM";
    partOf = [ "agent-vm.service" ];
    requires = [ "agent-vm-net.service" ];
    after = [ "agent-vm-net.service" ];
    serviceConfig = {
      #! под этим uid хостовый демон и увидит сборки гостя
      User = username;
      Restart = "on-failure";
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe pkgs.socat)
        "TCP-LISTEN:${toString net.nixDaemonPort},bind=${net.gateway},reuseaddr,fork"
        "UNIX-CONNECT:/nix/var/nix/daemon-socket/socket"
      ];
    };
  };

  systemd.services.agent-vm = {
    description = "Agent sandbox VM";
    #! TMPDIR — иначе run-agent-vm насыпет nix-vm.XXXX в /tmp и не уберёт.
    #! QMP — чтобы гасить гостя по ACPI, а не выдёргивать питание: SIGTERM
    #! уходит самому qemu, тот выходит мгновенно и docker теряет метаданные.
    environment = {
      TMPDIR = runDir;
      USE_TMPDIR = "1";
      QEMU_OPTS = "-qmp unix:${qmpSocket},server=on,wait=off";
    };
    requires = [ "agent-vm-net.service" ];
    wants = [
      "sing-box.service"
      "agent-nix-daemon.service"
    ];
    after = [
      "agent-vm-net.service"
      "sing-box.service"
      "agent-nix-daemon.service"
    ];
    serviceConfig = {
      User = username;
      SupplementaryGroups = [ "kvm" ];
      #! ждём выключения прямо здесь: сразу после ExecStop systemd шлёт SIGTERM,
      #! а гостю нужны секунды, чтобы размонтировать диск docker
      #! ACPI-выключение, пауза на размонтирование, затем добиваем через QMP.
      #! Сам гость до конца не гасится: systemd-shutdown залипает, потому что
      #! /nix/store (bind) занят и не отмонтируется, а 9p под ним уже сняли.
      #! К этому моменту /var/lib/docker размонтирован (наблюдаемо ~1.5 с),
      #! так что терять нечего. $MAINPID подставляет systemd в командную строку.
      ExecStop = "${pkgs.writeShellScript "agent-vm-stop" ''
        qmp() {
          printf '%s\n' '{"execute":"qmp_capabilities"}' "$1" |
            ${lib.getExe pkgs.socat} -t 2 - UNIX-CONNECT:${qmpSocket} >/dev/null 2>&1
        }
        qmp '{"execute":"system_powerdown"}' || exit 0
        n=0
        while kill -0 "''${1:-}" 2>/dev/null && [ $n -lt 15 ]; do
          ${lib.getExe' pkgs.coreutils "sleep"} 1
          n=$((n + 1))
        done
        kill -0 "''${1:-}" 2>/dev/null && qmp '{"execute":"quit"}'
        exit 0
      ''} $MAINPID";
      TimeoutStopSec = 45;
      ExecStartPre = pkgs.writeShellScript "agent-vm-pre" ''
        set -eu
        ${lib.getExe' pkgs.coreutils "mkdir"} -p ${runDir} ${dirOf sshKey}
        [ -f ${sshKey} ] ||
          ${lib.getExe' pkgs.openssh "ssh-keygen"} -q -t ed25519 -N "" -C agent-vm -f ${sshKey}
        [ -f ${dockerImage} ] ||
          ${lib.getExe' pkgs.qemu "qemu-img"} create -f qcow2 ${dockerImage} 32G
      '';
      ExecStart = lib.getExe vm;
    };
  };
}
