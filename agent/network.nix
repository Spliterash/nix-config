{ username, ... }: {
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
  stateDir = "/home/${username}/agent-vm";

  # Имена, уходящие в proxy-аутбаунд: apex и любая глубина.
  proxy = [
    "*.ipify.org"
    "*.openai.com"
    "*.anthropic.com"
  ];

  # Куда они уходят. Это outbound sing-box как в документации, любого типа
  # (socks, http, vless, trojan, ...) — только без "tag", его проставляем мы.
  #
  # Любую строку внутри можно заменить на { file = "..."; } — путь к файлу вне
  # стора, где лежит одно значение одной строкой. Либо задать весь outbound
  # одним JSON-файлом: outbound.file = "...". В обоих случаях содержимое
  # подставляет root перед стартом sing-box, в /nix/store уходит только путь.
  outbound = {
    # type = "socks";
    # server = "127.0.0.1";
    # server_port = 1080;
    # username = "sekai";
    # password = { file = "/home/${username}/agent-vm/socks-password"; };
  };
  outbound.file = "/home/${username}/agent-vm/proxy.json";

  # Каталоги хоста в гостя (9p, rw).
  mounts = [
    # { host = "/home/spliterash/projects"; guest = "/projects"; }
  ];
}
