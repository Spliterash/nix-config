{
  writeShellApplication,
  writeTextFile,
  symlinkJoin,
  systemd,
  openssh,
  coreutils,
  unit,
  sshHost,
}:
let
  cli = writeShellApplication {
    name = "avm";
    runtimeInputs = [
      systemd
      openssh
      coreutils
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

      cmd=''${1:-}
      shift || true

      case $cmd in
        start)
          systemctl start ${unit}
          wait_ssh
          ;;
        stop) systemctl stop ${unit} ;;
        restart)
          systemctl restart ${unit}
          wait_ssh
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
      )

      if (( CURRENT == 2 )); then
        _describe 'команда' cmds
        return
      fi

      case $words[2] in
        logs) _values 'источник' 'proxy' ;;
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
