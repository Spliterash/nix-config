# Проблема: ENFILE при доступе к смонтированному `/nix/store` в VM

Дата: 2026-09-23

## Симптомы

После нескольких успешных обращений к `/nix/store` почти любой процесс, запущенный из Bash,
начинает падать с `Error 23` (`ENFILE`, "Too many open files in system"):

- динамический загрузчик не может открыть библиотеки из `/nix/store`:
  ```
  head: error while loading shared libraries: libdl.so.2: cannot open shared object file: Error 23
  cut: error while loading shared libraries: libgmp.so.10: cannot open shared object file: No such file or directory
  tr: error while loading shared libraries: libcrypto.so.3: cannot open shared object file: No such file or directory
  ```
- обычные файлы и каталоги в store тоже не открываются:
  ```
  cat: /nix/store/85g6lr0jxw404ccy8m8y2yfra4xgdy69-source/pyproject.toml: Too many open files in system
  ls: cannot open directory '/nix/.ro-store/85g6lr0jxw404ccy8m8y2yfra4xgdy69-source': Too many open files in system
  bfs: error: .../python-telegram-bot-22.8/.../telegram/_utils: Too many open files in system.
  ```
- `cp -r` исходников Hermes из store в `/tmp` не проходит даже с повторами (10 попыток с паузой 15 с,
  перед этим пауза 90 с).

## Что показывает система

- `/proc/sys/fs/file-nr` → `795 0 9223372036854775807`: системная таблица файлов
  **не** заполнена, то есть ENFILE возвращает не ядро гостя.
- Уже запущенный процесс (инструмент Read в Claude Code) продолжает читать файлы из
  `/nix/store` без ошибок. Не открываются только **новые** файлы в новых процессах.
- Пауза от 20 до 90 с не помогает, состояние держится.

## Предположение

`/nix/store` (и `/nix/.ro-store`) проброшен в VM через общий FS (virtiofs / 9p / FUSE).
Лимит открытых дескрипторов исчерпан на стороне хоста или демона шаринга (например,
`virtiofsd` с низким `--rlimit-nofile`, или дескрипторы утекают из-за обхода большого дерева:
`find`/`bfs`/`grep -r` по `/nix/store`). Гость получает ENFILE от транспорта.

## Что спровоцировало

Рекурсивные обходы store: `find / -maxdepth 6 ...`, `find /nix/store ... -path "*site-packages*"`,
`grep -rn` по пакету python-telegram-bot, `cp -r` каталогов Hermes.

## Что стоит проверить / исправить

- Лимит дескрипторов у демона шаринга на хосте (`virtiofsd --rlimit-nofile=...`,
  `ulimit -n` сервиса) и режим кэша (`--cache=always` уменьшает число открытых inode-handle).
- Настройку `--inode-file-handles` / `--announce-submounts` у virtiofsd, если используется.
- Альтернатива: держать `/nix/store` на локальном диске VM (или overlay с локальным upper),
  а не на общей FS.
