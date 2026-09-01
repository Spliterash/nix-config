{ username, ... }:
let
  stateDir = "/home/${username}/agent-vm";
in
{
  # Линк хост↔гость на tap-agent. Подсеть должна быть свободна на хосте,
  # иначе agent-vm-net.service упадёт с "File exists".
  gateway = "10.234.0.1";
  guest = "10.234.0.2";
  prefixLength = 24;

  # Хостовый nix-daemon, проброшенный на gateway.
  nixDaemonPort = 54545;

  # Всё, что VM держит на диске: ssh-ключ, docker.qcow2, эфемерный корень,
  # временные файлы qemu. Путь абсолютный — run-agent-vm делает cd в свой
  # $TMPDIR перед запуском qemu, относительные уехали бы туда.
  inherit stateDir;
  configFile = stateDir + "/config.json";
}
