{
  writeShellApplication,
  writeTextFile,
  symlinkJoin,
  systemd,
  openssh,
  coreutils,
  jq,
  unit,
  sshHost,
  configFile,
  configTemplate,
  mountsJq,
}:
let
  cli = writeShellApplication {
    name = "avm";
    runtimeInputs = [
      systemd
      openssh
      coreutils
      jq
    ];
    text = ''
      usage() {
        cat <<'EOF'
      avm start              поднять VM и дождаться SSH
      avm stop               погасить
      avm restart            перезапустить
      avm status             запущена или нет
      avm ssh [команда...]   зайти внутрь; с аргументом — выполнить и выйти
      avm logs [proxy]       консоль VM; с proxy — лог прокси
      avm config [path]      открыть локальный конфиг или показать его путь
      EOF
      }

      wait_ssh() {
        local _
        for _ in $(seq 1 90); do
          if ssh -o BatchMode=yes -o ConnectTimeout=2 ${sshHost} true 2>/dev/null; then
            return 0
          fi
          systemctl is-active --quiet ${unit} || break
          sleep 1
        done
        echo "avm: SSH не поднялся, смотри avm logs" >&2
        return 1
      }

      mount_shares() {
        [[ -f ${configFile} ]] || return 0

        local i=0 mount host guest read_only kind tag options command
        local parent staging source
        while IFS= read -r mount; do
          host=$(jq -r '.host' <<<"$mount")
          guest=$(jq -r '.guest' <<<"$mount")
          read_only=$(jq -r '.readOnly' <<<"$mount")

          if [[ -d $host ]]; then
            kind='directory'
          elif [[ -f $host ]]; then
            kind='file'
          else
            echo "avm: mount[$i].host не является файлом или каталогом: $host" >&2
            return 1
          fi

          tag="avm$i"
          options=trans=virtio,version=9p2000.L,msize=16384
          [[ $read_only == true ]] && options+=,ro

          if [[ $kind == directory ]]; then
            printf -v command \
              'sudo mkdir -p -- %q && { sudo mountpoint -q -- %q || sudo mount -t 9p -o %q %q %q; }' \
              "$guest" "$guest" "$options" "$tag" "$guest"
          else
            parent=''${guest%/*}
            [[ -n $parent ]] || parent=/
            staging="/run/avm-mounts/$tag"
            source="$staging/source"
            printf -v command \
              'sudo mkdir -p -- %q %q && { sudo mountpoint -q -- %q || sudo mount -t 9p -o %q %q %q; } && { sudo test -e %q || sudo touch -- %q; } && { sudo mountpoint -q -- %q || sudo mount --bind %q %q; }' \
              "$parent" "$staging" "$staging" "$options" "$tag" "$staging" \
              "$guest" "$guest" "$guest" "$source" "$guest"
          fi

          # shellcheck disable=SC2029
          ssh -n ${sshHost} "$command"
          i=$((i + 1))
        done < <(jq -c '${mountsJq} | .[]' ${configFile})
      }

      edit_config() {
        local editor
        local -a editor_cmd

        mkdir -p "$(dirname ${configFile})"
        if [[ ! -e ${configFile} ]]; then
          install -m 600 ${configTemplate} ${configFile}
        fi
        chmod 600 ${configFile}

        editor=''${VISUAL:-''${EDITOR:-vi}}
        read -r -a editor_cmd <<<"$editor"
        "''${editor_cmd[@]}" ${configFile}
        jq empty ${configFile} >/dev/null || {
          echo "avm: ${configFile} содержит некорректный JSON" >&2
          return 1
        }
      }

      cmd=''${1:-}
      shift || true

      case $cmd in
        start)
          systemctl start ${unit}
          wait_ssh
          mount_shares
          ;;
        stop) systemctl stop ${unit} ;;
        restart)
          systemctl restart ${unit}
          wait_ssh
          mount_shares
          ;;
        status) systemctl status ${unit} --no-pager ;;
        ssh)
          # shellcheck disable=SC2029
          ssh ${sshHost} "$@"
          ;;
        logs)
          if [[ ''${1:-} == proxy ]]; then
            journalctl -u sing-box -f
          else
            journalctl -u ${unit} -f
          fi
          ;;
        config)
          if [[ ''${1:-} == path ]]; then
            printf '%s\n' ${configFile}
          elif (( $# == 0 )); then
            edit_config
          else
            echo "avm: config принимает только аргумент path" >&2
            exit 2
          fi
          ;;
        -h | --help | help) usage ;;
        *)
          usage >&2
          [[ -z $cmd ]] || echo "avm: неизвестная команда $cmd" >&2
          exit 2
          ;;
      esac
    '';
  };

  completion = writeTextFile {
    name = "avm-zsh-completion";
    destination = "/share/zsh/site-functions/_avm";
    text = ''
      #compdef avm

      local -a cmds
      cmds=(
        'start:поднять VM и дождаться SSH'
        'stop:погасить'
        'restart:перезапустить'
        'status:запущена или нет'
        'ssh:зайти внутрь или выполнить команду'
        'logs:консоль VM или лог прокси'
        'config:открыть локальный конфиг'
      )

      if (( CURRENT == 2 )); then
        _describe 'команда' cmds
        return
      fi

      case $words[2] in
        logs) _values 'источник' 'proxy' ;;
        config) _values 'действие' 'path' ;;
        ssh) _command_names -e ;;
      esac
    '';
  };
in
symlinkJoin {
  name = "avm";
  paths = [
    cli
    completion
  ];
  meta.mainProgram = "avm";
}
