# NixOS: рабочая памятка

## Где менять конфиг

- `flake.nix` — хосты `main` и `laptop`; `settings.nix` — общие параметры.
- `common/system/` — общие NixOS-модули; `common/home/` — Home Manager.
- `main/` и `laptop/` — настройки конкретного хоста, также разделены на `system/` и `home/`.
- `common/packages/` — собственные пакеты.
- Агентская VM: [agent/README.md](agent/README.md).

Рабочая копия ожидается в `~/config`. Применение на текущем хосте:

```bash
nh os build ~/config
nh os switch ~/config
```

## Данные и доступ

- При загрузке `/` откатывается к `zroot/root@blank`. Новые каталоги с важными
  данными добавляй в `common/system/impermanence.nix`, иначе они пропадут после ребута.
- `/persistent` сохраняется и снапшотится; `/shit` — сохраняемые кэши без
  автоснапшотов. Хранилище контейнеров в `/var/lib/docker` тоже без автоснапшотов.
  Снапшоты на том же диске не заменяют резервную копию.
- `laptop` использует шифрование ZFS с запросом пароля; `main` не зашифрован.
- После установки задай пароль через `passwd`. Начальный пароль указан в
  `common/system/default.nix` и не сбрасывает пароль существующего пользователя.
  Пароль пользователя и пароль ZFS независимы.
- SSH в установленную систему — только по ключу обычного пользователя, не root.
- Подпись Git включается вместе с GPG; ключ выбирается по email в `common/home/git.nix`.
  Перед первым коммитом импортируй или создай соответствующий приватный ключ.
  `~/.gnupg` сохраняется, но ключ и сертификат отзыва нужно резервировать отдельно.
  Не помещай их в Git или Nix store.

## Переустановка laptop с main

**Disko стирает весь SSD, указанный в `laptop/system/disk-config.nix`, включая
существующую Windows.** Создаёт ESP 2 GiB и зашифрованный ZFS, оставляет около
100 GiB под Windows. Сначала сделай резервную копию и проверь целевой диск.
Обычный rebuild диск не переразмечает; уменьшить существующий ZFS на месте нельзя.

Загрузи ноутбук с NixOS live-ISO, подключи сеть и обеспечь SSH-доступ root.
Следующие команды выполняются на `main` в Bash из корня репозитория;
замени `<ip>` адресом ноутбука:

```bash
TARGET='root@<ip>'
ssh "$TARGET" 'hostname; lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS,MODEL; readlink -f /dev/disk/by-id/nvme-Micron_MTFDHBA512QFD_20432B2E2878'
ssh-copy-id "$TARGET"
ssh "$TARGET" 'nixos-generate-config --no-filesystems --show-hardware-config' \
  > laptop/system/hardware-configuration.nix

P=$(nix build .#nixosConfigurations.laptop.config.system.build.diskoScript --print-out-paths --no-link)
nix copy --to "ssh://$TARGET" --no-check-sigs "$P"
```

Запуск разметки; пароль ZFS — не менее 8 символов, не записывай его в команду:

```bash
read -r -s -p 'Пароль ZFS: ' PASSPHRASE; printf '\n'
printf '%s\n%s\n' "$PASSPHRASE" "$PASSPHRASE" | ssh "$TARGET" "$P"
unset PASSPHRASE
```

Только после успешной разметки и монтирования `/mnt`:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#laptop --phases install,reboot --target-host "$TARGET"
```

Фаза `reboot` экспортирует пул. Если перезагружаешь live-систему вручную,
сначала выполни **на ноутбуке** `umount /mnt/boot` и `zpool export zroot`:
иначе `forceImportRoot = false` не позволит загрузиться с пулом, оставшимся
импортированным под hostid установщика.

Windows устанавливай в свободное место, не форматируя EFI и ZFS.
Secure Boot в этом конфиге не настроен. Рабочую копию в `~/config` после
установки нужно разместить самостоятельно.

### Особенность main

`main/system/disk-config.nix` сохраняет таблицу разделов (`destroy = false`),
но не описывает ZFS-раздел и ESP. Это **не готовый сценарий установки с нуля**:
перед переустановкой нужно определить существующие разделы, подключить нужный
раздел к пулу в disko и учесть монтирование ESP. Не применяй к этому диску
разметку ноутбука — рядом находится Windows.

## Контейнеры

На хостах используется rootless Podman; `docker` — совместимая команда,
Compose — `podman-compose`. Конфиг: `common/system/docker.nix`.

- Docker API: `unix://$XDG_RUNTIME_DIR/podman/podman.sock`.
  После изменения окружения перелогинься; проверка сокета —
  `systemctl --user status podman.socket`.
- `~/.local/share/containers` сохраняется на ZFS dataset `zroot/docker`,
  смонтированном в `/var/lib/docker`. Старые данные Docker автоматически не импортируются.
- `keep-id` включается только для отдельных сервисов через `userns_mode` в Compose.
- `:U` у bind mount рекурсивно меняет владельцев файлов на хосте.
- Данные PostgreSQL храни на Linux-ФС, не NTFS.

## Syncthing

GUI: `http://127.0.0.1:8384`. В `common/home/syncthing.nix` включены только
пользовательская служба и трей. Устройства, папки и исключения настраиваются
в GUI; декларативного `.stignore` для OMP сейчас нет.

- Для `~/.omp` до включения синхронизации задай исключения: не переноси сессии,
  историю, SQLite-базы и runtime-состояние. `~/config` обновляй через Git.
- Для Minecraft: `main` — `/mnt/data/Games/Minecraft/Prism/instances`,
  `laptop` — `~/.local/share/FreesmLauncher/instances`. Включи Ignore Permissions
  на обеих сторонах из-за NTFS на ПК. Эти данные на NTFS не покрываются ZFS-снапшотами.
- Перед сменой устройства закрой игру и дождись синхронизации.
  Удаления распространяются между устройствами; живые миры безопасно не объединяются.

## Графика laptop

Встроенный экран подключён к AMD, HDMI — к NVIDIA. Запуск на дискретной карте:
`nvidia-offload <команда>`. PCI-адреса и драйвер заданы в `laptop/system/gpu.nix`;
при смене железа или режима GPU в BIOS их нужно перепроверить.
После изменений графики проверяй запрос пароля ZFS, сон/пробуждение и HDMI на ноутбуке.
