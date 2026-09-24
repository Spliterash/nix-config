{
  writeShellApplication,
  writeTextFile,
  symlinkJoin,
  systemd,
  openssh,
  coreutils,
  yq,
  vm,
}:
let
  cli = writeShellApplication {
    name = "avm";
    runtimeInputs = [
      systemd
      openssh
      coreutils
      yq
    ];
    text = ''
      usage() {
        cat <<'EOF'
      avm start              поднять VM и дождаться загрузки
      avm stop               погасить
      avm restart            перезапустить
      avm status             запущена или нет
      avm ssh [команда...]   зайти внутрь; с аргументом — выполнить и выйти
      avm logs [proxy]       консоль VM; с proxy — лог внешнего прокси
      avm config [path]      открыть локальный конфиг или показать его путь
      EOF
      }

      wait_boot() {
        local _
        for _ in $(seq 1 90); do
          if ssh -o BatchMode=yes -o ConnectTimeout=2 ${vm.name} true 2>/dev/null; then
            ssh ${vm.name} systemctl is-system-running --wait >/dev/null || true
            return 0
          fi
          systemctl is-active --quiet ${vm.unit} || break
          sleep 1
        done
        echo "avm: VM не поднялась, смотри avm logs" >&2
        return 1
      }

      edit_config() {
        local editor
        local -a editor_cmd

        mkdir -p "$(dirname ${vm.configFile})"
        if [[ ! -e ${vm.configFile} ]]; then
          (umask 077 && printf '%s\n' 'proxy: []' 'outbound: null' 'mounts: []' >${vm.configFile})
        fi
        chmod 600 ${vm.configFile}

        editor=''${VISUAL:-''${EDITOR:-vi}}
        read -r -a editor_cmd <<<"$editor"
        "''${editor_cmd[@]}" ${vm.configFile}
        yq -e -s 'length == 1 and (.[0] | type == "object")' ${vm.configFile} >/dev/null || {
          echo "avm: ${vm.configFile} должен содержать один YAML-объект" >&2
          return 1
        }
      }

      cmd=''${1:-}
      shift || true

      case $cmd in
        start)
          systemctl start ${vm.unit}
          wait_boot
          ;;
        stop) systemctl stop ${vm.unit} ;;
        restart)
          systemctl restart ${vm.unit}
          wait_boot
          ;;
        status) systemctl status ${vm.unit} --no-pager ;;
        ssh)
          # shellcheck disable=SC2029
          ssh ${vm.name} "$@"
          ;;
        logs)
          if [[ ''${1:-} == proxy ]]; then
            journalctl -u ${vm.unit} -t avm-proxy -f
          else
            journalctl -u ${vm.unit} -f
          fi
          ;;
        config)
          if [[ ''${1:-} == path ]]; then
            printf '%s\n' ${vm.configFile}
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
        'start:поднять VM и дождаться загрузки'
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
