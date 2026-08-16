# Agent VM

Виртуалка для LLM-агента. Внутри агент может делать что угодно, наружу ходит
только через хост: выбранные имена — в SOCKS5, остальное — напрямую.

## Пользоваться

```sh
avm start            # поднять и дождаться, пока пустит по SSH
avm ssh              # зайти внутрь
avm ssh htop         # выполнить команду и выйти
avm stop             # погасить
```

Ещё:

```sh
avm status           # запущена или нет
avm restart
avm logs             # консоль VM
avm logs proxy       # куда уходит трафик
```

Есть таб-комплит: `avm <Tab>`. Пароль не спрашивает.

Сама по себе виртуалка не стартует — только руками.

## Настроить

Всё в одном файле — `agent/network.nix`. После правки нужен `nn`
(пересборка системы), иначе изменения не подхватятся.

**Какие имена идут через прокси.** `*.` означает и сам домен, и любые
поддомены:

```nix
proxy = [
  "*.openai.com"
  "*.anthropic.com"
];
```

Что не попало в список — идёт напрямую. Если прокси лежит, эти имена просто
не открываются, остальное продолжает работать.

**Куда их отправлять.** Это outbound из документации sing-box, любого типа —
`socks`, `http`, `vless`, `trojan` и так далее. Поле `tag` писать не надо, оно
проставляется само:

```nix
outbound = {
  type = "socks";
  server = "127.0.0.1";
  server_port = 1080;
};
```

С логином и паролем:

```nix
outbound = {
  type = "socks";
  server = "10.9.8.7";
  server_port = 1080;
  username = "sekai";
  password = "hunter2";
};
```

Справочник по полям — [sing-box.sagernet.org/configuration/outbound](https://sing-box.sagernet.org/configuration/outbound/).

**Папки хоста внутрь VM:**

```nix
mounts = [
  { host = "/home/spliterash/projects"; guest = "/projects"; }
];
```

## Если пароль нельзя в git

Любую строку внутри `outbound` можно заменить на `{ file = "..."; }` — путь к
файлу вне репозитория. В файле лежит только само значение, одной строкой.
Ни в git, ни в `/nix/store` оно не попадёт: содержимое подставляет root
непосредственно перед стартом sing-box.

Кладём пароль:

```sh
printf 'hunter2\n' > ~/agent-vm/socks-password
chmod 600 ~/agent-vm/socks-password
```

И ссылаемся на него:

```nix
outbound = {
  type = "socks";
  server = "10.9.8.7";
  server_port = 1080;
  username = "sekai";
  password = { file = "/home/spliterash/agent-vm/socks-password"; };
};
```

Так можно с любым полем, не только с паролем — например, если и адрес прокси
светить не хочется:

```nix
outbound = {
  type = "socks";
  server = { file = "/home/spliterash/agent-vm/socks-server"; };
  server_port = 1080;
  username = { file = "/home/spliterash/agent-vm/socks-username"; };
  password = { file = "/home/spliterash/agent-vm/socks-password"; };
};
```

Один файл — одно значение. Числа (как `server_port`) так задать нельзя, они
остаются в `network.nix`.

## Или весь outbound одним файлом

Если из репозитория надо убрать вообще всё — пиши outbound целиком в JSON.
Тег в него по-прежнему не нужен:

```sh
cat > ~/agent-vm/outbound.json <<'EOF'
{
  "type": "socks",
  "server": "10.9.8.7",
  "server_port": 1080,
  "username": "sekai",
  "password": "hunter2"
}
EOF
chmod 600 ~/agent-vm/outbound.json
```

В `network.nix` тогда вместо всего блока `outbound = { ... }`:

```nix
outbound.file = "/home/spliterash/agent-vm/outbound.json";
```

Формат файла — ровно то, что в
[документации по outbound](https://sing-box.sagernet.org/configuration/outbound/),
так что тем же способом задаётся не только socks: `vless`, `trojan`,
`shadowsocks` и остальные пишутся туда как есть.

## Файлы

Всё лежит в `~/agent-vm`:

| | |
|---|---|
| `ssh/` | ключ, которым `avm ssh` заходит внутрь |
| `docker.qcow2` | образы и контейнеры docker |
| `root.qcow2`, `run/` | директория рута за исключением монтирования |

Ключ генерится сам при первом `avm start`, в репозитории его нет. Потерялся —
удали `~/agent-vm/ssh` и запусти снова, сделается новый.

Каталог можно переносить целиком: путь задаётся в `network.nix` (`stateDir`).

## Что переживает перезапуск

| | |
|---|---|
| Образы и контейнеры docker | да |
| Всё остальное внутри VM | нет, корень чистый на каждый старт |
| Скачанное через `nix-shell` / `nix build` | да, попадает в store хоста |

Файлы внутри `mounts` живут на хосте, их VM не трогает.

Docker начать с нуля: `avm stop && rm ~/agent-vm/docker.qcow2`.
