{
  lib,
  pkgs,
  inputs,
  system,
  username,
  flakePath,
  ...
}@allInputs:
let
  vm = import ./vm.nix allInputs;
  network = import ./network.nix { inherit lib pkgs vm; };

  prepare = pkgs.writeShellApplication {
    name = "avm-prepare";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      openssh
      util-linux
      yq
    ];
    text = ''
      umask 077
      config=${vm.configFile}
      [[ -f $config ]] || config=${pkgs.writeText "empty.yml" "{}"}

      # host:guest[:ro|rw] и одиночная запись приводятся к массиву объектов
      yq . "$config" | jq -e -s '
        def abs: type == "string" and startswith("/");
        if length == 1 and (.[0] | type == "object") then .[0]
        else error("config.yml должен содержать один YAML-объект") end
        |
        .mounts |= (. // [] | if type == "array" then . else [.] end | map(
          if type == "string" then
            split(":") as $p
            | if ($p | length) <= 3 and ($p[2] // "rw" | IN("ro", "rw"))
              then { host: $p[0], guest: $p[1], readOnly: ($p[2] == "ro") }
              else error("некорректный mount: \(.)") end
          else . end))
        | .proxy //= []
        | if all(.mounts[]; (.host | abs) and (.guest | abs) and (.readOnly // false | type == "boolean"))
            and (.proxy | type == "array" and all(.[]; type == "string" and (ltrimstr("*.") | length > 0)))
            and ((.proxy | length) == 0 or (.outbound | type == "object"))
          then . else error("некорректный config.yml") end
      ' >/run/avm/config.json

      install -d -o ${username} -m 700 "$(dirname ${vm.sshKey})"
      [[ -f ${vm.sshKey} ]] ||
        runuser -u ${username} -- ssh-keygen -q -t ed25519 -N "" -C avm -f ${vm.sshKey}

      install -d -m 755 ${vm.hostDir} ${vm.sharesDir}
      install -d -o ${username} -g kvm -m 770 ${vm.stateDir}/disks
      install -d -m 755 ${vm.disksDir}
      mount --bind ${vm.stateDir}/disks ${vm.disksDir}
      install -m 644 ${vm.sshKey}.pub ${vm.hostDir}/authorized_keys

      #! файл отдаётся через bind на файл внутри шары, соседи по каталогу гостю не видны
      i=0
      while IFS=$'\t' read -r host read_only; do
        target=${vm.sharesDir}/$i
        if [[ -d $host ]]; then
          mkdir "$target"
        elif [[ -f $host ]]; then
          touch "$target"
        else
          echo "avm: mounts[$i].host не существует: $host" >&2
          exit 1
        fi
        mount --bind "$host" "$target"
        [[ $read_only == false ]] || mount -o remount,bind,ro "$target"
        i=$((i + 1))
      done < <(jq -r '.mounts[] | [.host, .readOnly // false] | @tsv' /run/avm/config.json)
      jq '[.mounts[].guest]' /run/avm/config.json >${vm.hostDir}/mounts.json

      #! proxy.json с секретами читает только root, гостю конфиг не отдаём
      (umask 077 && jq --slurpfile p /run/avm/config.json '
        if ($p[0].proxy | length) > 0 then
          .outbounds += [$p[0].outbound + { tag: "proxy" }]
          | .route.rules += [{ domain_suffix: [$p[0].proxy[] | ltrimstr("*.")], outbound: "proxy" }]
        else . end
      ' ${network.proxyConfig} >/run/avm/proxy.json)
      rm /run/avm/config.json
    '';
  };

  #! без --one-file-system rm ушёл бы внутрь не отмонтированной шары на хосте
  cleanup = pkgs.writeShellScript "avm-cleanup" ''
    set -euo pipefail
    shopt -s nullglob
    for target in ${vm.sharesDir}/* ${vm.disksDir}; do
      if ${lib.getExe' pkgs.util-linux "mountpoint"} -q "$target"; then
        ${lib.getExe' pkgs.util-linux "umount"} "$target"
      fi
    done
    ${lib.getExe' pkgs.coreutils "rm"} -rf --one-file-system /run/avm
  '';

  avm = pkgs.callPackage ./avm.nix { inherit vm; };
in
{
  imports = [ inputs.microvm.nixosModules.host ];

  microvm.vms.${vm.name} = {
    config = ./default.nix;
    specialArgs = {
      inherit
        inputs
        system
        username
        flakePath
        ;
    };
    autostart = false;
    restartIfChanged = false;
  };

  systemd.services.avm-prepare = {
    description = "Mounts and runtime config for the agent VM";
    requiredBy = [ "microvm-virtiofsd@${vm.name}.service" ];
    before = [ "microvm-virtiofsd@${vm.name}.service" ];
    partOf = [ vm.unit ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = [
        "${cleanup}"
        "${lib.getExe' pkgs.coreutils "install"} -d -m 711 /run/avm"
      ];
      ExecStart = lib.getExe prepare;
      ExecStopPost = cleanup;
    };
  };

  # гостевой root выключает VM — не надо её тут же поднимать обратно
  systemd.services."microvm@${vm.name}".serviceConfig = {
    Restart = lib.mkForce "on-failure";
    ExecStart = lib.mkForce [
      ""
      "+${lib.getExe network.start} /var/lib/microvms/${vm.name}/current/bin/microvm-run"
    ];
    KillMode = "mixed";
    ExecStopPost = [ "-+${lib.getExe' pkgs.iproute2 "ip"} netns delete avm" ];
  };

  systemd.sockets.avm-nix-daemon = {
    description = "host nix-daemon for the agent VM (vsock)";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "vsock::${toString vm.nixDaemonPort}" ];
  };
  systemd.services.avm-nix-daemon.serviceConfig = {
    #! под этим uid хостовый демон и увидит сборки гостя
    User = username;
    ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd /nix/var/nix/daemon-socket/socket";
  };

  environment.systemPackages = [ avm ];

  #! чтобы avm start/stop не спрашивал пароль; правило только про этот юнит
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "${vm.unit}" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  programs.ssh.extraConfig = ''
    Host ${vm.name}
      User ${username}
      ProxyCommand ${pkgs.systemd}/lib/systemd/systemd-ssh-proxy vsock/${toString vm.vsockCid} 22
      ProxyUseFdpass yes
      IdentityFile ${vm.sshKey}
      IdentitiesOnly yes
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
      LogLevel ERROR
  '';
}
