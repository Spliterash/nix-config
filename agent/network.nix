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
  stateDir = "/home/spliterash/agent-vm";

  # Имена, уходящие в proxy-аутбаунд: apex и любая глубина.
  proxy = [
    "*.ipify.org"
    "*.openai.com"
    "*.anthropic.com"
  ];

  # Куда их отправлять. Либо адрес SOCKS5 строкой, либо { file = "..."; } —
  # путь к JSON вне стора, чтобы адрес и креды не попали ни в git, ни в
  # /nix/store. Файл читает root перед стартом sing-box; в нём лежит готовый
  # outbound с "tag": "proxy" — любого типа, не только socks.
  socks5 = "127.0.0.1:1080";
  # socks5.file = "/etc/agent-vm/outbound.json";

  # Каталоги хоста в гостя (9p, rw).
  mounts = [
    # { host = "/home/spliterash/projects"; guest = "/projects"; }
  ];
}
