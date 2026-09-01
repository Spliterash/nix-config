{
  lib,
  pkgs,
  self,
  username,
  ...
}@allInputs:
let
  net = import ./network.nix allInputs;
  vm = self.nixosConfigurations.agent.config.system.build.vm;

  tap = "tap-agent";
  tun = "sb-agent";
  sshHost = "agent";

  runDir = "${net.stateDir}/run";
  qmpSocket = "${runDir}/qmp.sock";
  sshKey = "${net.stateDir}/ssh/id_ed25519";
  dockerImage = "${net.stateDir}/docker.qcow2";
  fileShares = "/run/agent-vm-files";

  emptyConfig = pkgs.writeText "agent-vm-empty-config.json" "{}";
  configTemplate = (pkgs.formats.json { }).generate "agent-vm-config.json" {
    proxy = [ ];
    outbound = null;
    mounts = [ ];
  };

  mountsJq = ''
    def mount_items:
      (.mounts // []) | if type == "array" then . else [.] end;
    def normalize_mount:
      if type == "string" then
        split(":") as $parts | {
          host: $parts[0],
          guest: $parts[1],
          readOnly: (($parts[2] // "rw") == "ro")
        }
      else
        {
          host: .host,
          guest: .guest,
          readOnly: (.readOnly // false)
        }
      end;
    [mount_items[] | normalize_mount]
  '';

  avm = pkgs.callPackage ./avm.nix {
    inherit sshHost configTemplate mountsJq;
    configFile = net.configFile;
    unit = "agent-vm.service";
  };

  configCheck = ''
    def proxy_list:
      type == "array" and all(.[];
        type == "string" and (ltrimstr("*.") | length > 0)
      );
    def absolute_path:
      type == "string" and length > 0 and startswith("/");
    def mount_item:
      if type == "object" then
        (.host | absolute_path)
        and (.guest | absolute_path)
        and ((has("readOnly") | not) or (.readOnly | type == "boolean"))
      elif type == "string" then
        split(":") as $parts
        | (($parts | length) == 2 or ($parts | length) == 3)
        and ($parts[0] | absolute_path)
        and ($parts[1] | absolute_path)
        and (($parts | length) == 2 or ($parts[2] == "ro" or $parts[2] == "rw"))
      else
        false
      end;
    def mount_list:
      (if type == "array" then . else [.] end) | all(.[]; mount_item);
    type == "object"
    and ((.proxy // []) | proxy_list)
    and ((.mounts // []) | mount_list)
    and (((.proxy // []) | length) == 0 or (.outbound | type == "object"))
  '';

  cleanupMounts = pkgs.writeShellScript "agent-vm-cleanup-mounts" ''
    shopt -s nullglob
    for source in ${fileShares}/avm*/source; do
      ${lib.getExe' pkgs.util-linux "umount"} "$source" 2>/dev/null || true
    done
    ${lib.getExe' pkgs.coreutils "rm"} -rf ${fileShares}
  '';

  prepareMounts = pkgs.writeShellScript "agent-vm-prepare-mounts" ''
    set -euo pipefail
    config=${lib.escapeShellArg net.configFile}
    [[ -f "$config" ]] || config=${emptyConfig}

    ${lib.getExe pkgs.jq} -e '${configCheck}' "$config" >/dev/null || {
      echo "agent-vm: некорректный локальный конфиг $config" >&2
      exit 1
    }
    ${cleanupMounts}
    ${lib.getExe' pkgs.coreutils "install"} -d -m 0755 ${fileShares}

    i=0
    while IFS= read -r mount; do
      host=$(${lib.getExe pkgs.jq} -r '.host' <<<"$mount")
      if [[ -f "$host" ]]; then
        share=${fileShares}/avm$i
        ${lib.getExe' pkgs.coreutils "install"} -d -m 0755 "$share"
        ${lib.getExe' pkgs.coreutils "touch"} "$share/source"
        ${lib.getExe' pkgs.util-linux "mount"} --bind "$host" "$share/source"
      fi
      i=$((i + 1))
    done < <(${lib.getExe pkgs.jq} -c '${mountsJq} | .[]' "$config")
  '';

  proxyOutboundFile = "/run/sing-box/proxy-outbound.secret";
  proxyRulesFile = "/run/sing-box/proxy-rules.secret";
  prepProxy = pkgs.writeShellScript "agent-vm-proxy" ''
    set -euo pipefail
    config=${lib.escapeShellArg net.configFile}
    [[ -f "$config" ]] || config=${emptyConfig}

    ${lib.getExe pkgs.jq} -e '${configCheck}' "$config" >/dev/null || {
      echo "agent-vm: некорректный локальный конфиг $config" >&2
      exit 1
    }
    ${lib.getExe pkgs.jq} '
      if ((.proxy // []) | length) == 0 then
        { type: "direct", tag: "proxy" }
      else
        .outbound + { tag: "proxy" }
      end
    ' "$config" >${proxyOutboundFile}
    ${lib.getExe pkgs.jq} '[
      if ((.proxy // []) | length) > 0 then
        { domain_suffix: [.proxy[] | ltrimstr("*.")] }
      else
        { domain_regex: ["a^"] }
      end
    ]' "$config" >${proxyRulesFile}
  '';

  startVm = pkgs.writeShellScript "agent-vm-start" ''
    set -euo pipefail
    config=${lib.escapeShellArg net.configFile}
    [[ -f "$config" ]] || config=${emptyConfig}

    ${lib.getExe pkgs.jq} -e '${configCheck}' "$config" >/dev/null || {
      echo "agent-vm: некорректный локальный конфиг $config" >&2
      exit 1
    }

    qemu_args=(
      -qmp
      ${lib.escapeShellArg "unix:${qmpSocket},server=on,wait=off"}
    )
    i=0
    while IFS= read -r mount; do
      host=$(${lib.getExe pkgs.jq} -r '.host' <<<"$mount")
      read_only=$(${lib.getExe pkgs.jq} -r '.readOnly' <<<"$mount")
      if [[ -d "$host" ]]; then
        export_path=$host
      elif [[ -f "$host" ]]; then
        export_path=${fileShares}/avm$i
      else
        echo "agent-vm: mount[$i].host не является файлом или каталогом: $host" >&2
        exit 1
      fi
      virtfs="local,path=$export_path,security_model=none,mount_tag=avm$i"
      [[ $read_only == true ]] && virtfs+=,readonly=on
      qemu_args+=(
        -virtfs
        "$virtfs"
      )
      i=$((i + 1))
    done < <(${lib.getExe pkgs.jq} -c '${mountsJq} | .[]' "$config")

    exec ${lib.getExe vm} "''${qemu_args[@]}"
  '';

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
        {
          _secret = proxyOutboundFile;
          quote = false;
        }
      ];
      route = {
        default_domain_resolver = "local";
        auto_detect_interface = true;
        final = "direct";
        rule_set = [
          {
            type = "inline";
            tag = "proxy";
            rules = {
              _secret = proxyRulesFile;
              quote = false;
            };
          }
        ];
        rules = [
          { action = "sniff"; }
          {
            protocol = "dns";
            action = "hijack-dns";
          }
          {
            rule_set = [ "proxy" ];
            action = "route";
            outbound = "proxy";
          }
        ];
      };
    };
  };

  systemd.services.sing-box = {
    serviceConfig.ExecStartPre = lib.mkMerge [
      (lib.mkBefore [ "+${prepProxy}" ])
      (lib.mkAfter [ "${lib.getExe pkgs.sing-box} check -c /run/sing-box/config.json" ])
    ];
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
    };
    requires = [
      "agent-vm-net.service"
      "sing-box.service"
    ];
    wants = [
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
      ExecStartPre = [
        "+${prepareMounts}"
        (pkgs.writeShellScript "agent-vm-pre" ''
          set -eu
          ${lib.getExe' pkgs.coreutils "mkdir"} -p ${runDir} ${dirOf sshKey}
          [ -f ${sshKey} ] ||
            ${lib.getExe' pkgs.openssh "ssh-keygen"} -q -t ed25519 -N "" -C agent-vm -f ${sshKey}
          [ -f ${dockerImage} ] ||
            ${lib.getExe' pkgs.qemu "qemu-img"} create -f qcow2 ${dockerImage} 32G
        '')
      ];
      ExecStart = startVm;
      ExecStopPost = "+${cleanupMounts}";
    };
  };
}
