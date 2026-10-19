# Установка

Флейк на несколько хостов. Каждый хост живёт в `<имя>/` (папка верхнего уровня)
и собирается как `nixosConfigurations.<имя>` (сейчас есть `main` и `laptop`).

Структура host-центричная: всё общее — в `common/`, всё host-only — в папке
своего хоста. Внутри каждой папки разделение `system/` (NixOS) и `home/`
(home-manager).

```
common/              — общее для всех хостов
  system/            — системные NixOS-модули (вкл. nix.nix, impermanence.nix)
  home/              — home-manager конфиг (общий)
  packages/          — кастомные пакеты (sniffcraft, photocraft, locales-iso)
main/                — десктоп (AMD GPU, установлен и работает)
  system/            — точка входа (default.nix) + hardware/disk/gpu, powersaving
  home/              — home-manager: софт этого хоста
laptop/              — ноут (NVIDIA)
  system/            — точка входа (default.nix) + hardware/disk/gpu
  home/              — home-manager этого хоста
```

PhotoCraft подключён в `common/home/soft/packages.nix`: версия `0.3.0` и SHA-256
релизного архива закреплены в `common/packages/photocraft.nix`. Пакет включает
пункт меню с описанием и иконкой; настройки сохраняются самим приложением в
`${XDG_CONFIG_HOME:-~/.config}/photocraft/preferences.json`.

Разметка диска (GPT, EFI-раздел, раздел под ZFS) — единственный ручной шаг:
диск общий с Windows (двачбут), и disko не может размечать автоматически, не
зная где чужие разделы. Всё остальное — пул, датасеты, шифрование, снапшот
для имперманенса, монтирование под `/mnt` — делает готовый скрипт disko
одной командой (см. пункт 4), руками ничего создавать/монтировать/grep'ать
не нужно.

Исключение — `laptop`: его `laptop/system/disk-config.nix` описывает весь
layout — ESP 2 GiB, раздел под ZFS и около 100 GiB незанятого места в конце
диска для Windows (`end = "-100G"`). Disko размечает диск и монтирует ESP сам —
ручная разметка (§2) и ручное монтирование ESP (§4) не нужны. Переустановка
удалённая с `main` через `nixos-anywhere` — см. отдельный раздел ниже.

## 0. Что нужно знать заранее

- Каждый хост — отдельный `networking.hostId` (обязателен для ZFS) и
  `networking.hostName`. Уже прописаны в `<имя>/system/default.nix`.
- Имперманенс: корень (`/`) откатывается к чистому ZFS-снапшоту
  `zroot/root@blank` при каждой загрузке (см. `common/system/impermanence.nix`). Всё, что
  должно пережить перезагрузку, лежит в `/persistent` (и `/shit` — для
  кэшей типа `.cache`/`.gradle`/`.npm`, которые не обязательно снапшотить).
  Снапшот создаётся автоматически при создании пула (`postCreateHook` в
  `<имя>/system/disk-config.nix`) — руками ничего делать не нужно.
- Шифрование пула (native ZFS encryption, `keylocation=prompt`) — только у
  `laptop`. `main` без шифрования. Смотри сам `<имя>/system/disk-config.nix` нужного
  хоста, а не эту инструкцию, если не уверен. Файла с ключом нигде нет —
  пароль спрашивается интерактивно в терминале при создании пула (пункт 4).
  При загрузке `laptop` запрос идёт через systemd-initrd и Plymouth с темой
  Breeze; для графической формы нужен работающий видеовывод в initrd.
- Если рядом стоит Windows на том же диске — сначала ставь/оставь Windows,
  EFI-раздел общий на оба ОС.
- На `main` включена zram-подкачка объёмом 50% RAM (`main/system/default.nix`):
  страницы сжимаются в оперативной памяти, дисковый swap не создаётся.
  Это запас для сжимаемых данных, а не гарантия от OOM. Проверка после применения:
  `swapon --show` и `zramctl`.

## 1. Загрузка установщика

Скачай NixOS minimal ISO, запиши на флешку, загрузись. Подключи сеть
(`nmtui` в графическом окружении установщика или `nmcli` в консоли).

## 2. Разметка диска

Определи целевой диск:

```bash
ls -la /dev/disk/by-id/
```

Через `gdisk`/`parted`/`cfdisk` создай GPT со следующими разделами:

1. **EFI System Partition** — ~512 МиБ–1 ГиБ, тип `ef00`, `mkfs.vfat -F32`.
   Если диск общий с Windows и ESP уже есть — используй его, новый не нужен.
2. **Раздел под ZFS** — весь оставшийся простор. Больше ничего с ним делать
   не нужно, пул создаётся на следующем шаге.

(Если ставишь рядом с Windows и хочешь его сохранить — раздел Windows,
разумеется, не трогай.)

## 3. Правки в репозитории под конкретный хост

Клонируй этот репозиторий (или скопируй флешкой) куда угодно, например
`/tmp/config`. После установки рабочую копию в `/home/<юзер>/config`
нужно разместить самостоятельно; автоматического клонирования нет.

Для **нового** хоста (по образцу `laptop/`, если ставишь именно
ноут — эти правки уже сделаны, просто проверь):

- `<имя>/system/disk-config.nix` — замени `REPLACE_ME_AT_INSTALL` на реальный
  `/dev/disk/by-id/...` раздела под ZFS (без `-partN`, просто путь родителя,
  как в `main/system/disk-config.nix`, либо сразу с `-partN`, если раздел уже
  существует — смотри на `content.type = "gpt"` в файле, определяет, ждёт
  ли disko целый диск или готовый раздел).
- `networking.hostId` в `<имя>/system/default.nix` — уже задан уникально,
  трогать не нужно, только не копируй один и тот же id на два хоста.

## 4. Диск: пул, датасеты, монтирование — одной командой

Disko компилирует твой `disk-config.nix` в готовый скрипт, который сам
создаёт ZFS-пул, датасеты, снапшот для имперманенса и монтирует всё под
`/mnt` — за один запуск, без ручного `zpool create`/`zfs create`/`mount`:

```bash
sudo "$(nix build .#nixosConfigurations.<имя>.config.system.build.diskoScript --print-out-paths --no-link)"
```

Если ставишь `laptop` — пул зашифрован, скрипт остановится на
`Enter new passphrase:` (дважды, для подтверждения) и спросит пароль прямо в
терминале. `main` не зашифрован, ничего спрашивать не будет.

После этого под `/mnt` уже смонтированы `/`, `/persistent`, `/nix`,
`/var/lib/docker`, `/shit`. ESP скрипт не трогает (он не описан в
`disk-config.nix`) — монтируешь сам:

```bash
mkdir -p /mnt/boot
mount /dev/disk/by-id/<esp-раздел> /mnt/boot
```

## 5. Установка

```bash
nixos-generate-config --no-filesystems --root /mnt
```

Перенеси нужные секции (`boot.initrd.availableKernelModules`,
`boot.initrd.kernelModules`, `boot.kernelModules`, `hardware.cpu.*`,
`fileSystems."/boot"` с реальным UUID ESP) в
`<имя>/system/hardware-configuration.nix`, заменив там заглушку.

Дальше:

```bash
cd /path/to/config   # где лежит flake.nix
sudo nixos-install --flake .#<имя> --root /mnt
```

В `common/system/default.nix` задан `initialPassword = "init"` без хеша.
Он применяется только при создании пользователя. После установки смени его
через `passwd`; rebuild больше не сбрасывает пароль существующего аккаунта.
Если система установлена со старым конфигом, прежний пароль сохраняется.

## 6. Первая загрузка

Перезагрузись, убери флешку. На `laptop` сначала введи пароль ZFS в Plymouth.
После разблокировки пула автологин в Plasma
(`common/system/desktop-environment.nix`) открывает рабочий стол.

На `laptop` включена автоматическая блокировка экрана и блокировка после сна;
для разблокировки требуется пароль пользователя без беспарольного периода
(`laptop/home/power.nix`). Пароль ZFS и пароль пользователя — разные настройки.

На обоих хостах включён SSH только по ключу для обычного пользователя;
парольный вход и вход root запрещены. Начальный публичный ключ `main`
добавлен декларативно: доступ не зависит от получения `~/.ssh` через Syncthing.

Конфиг в `/home/<юзер>/config` обновляется вручную через Git; этот каталог
не синхронизируется Syncthing.

## Docker на хостах

На `main` и `laptop` включён штатный `virtualisation.docker.rootless` с
`setSocketVariable = true`. Системный rootful-демон отключён, пользователь больше
не добавляется в группу `docker`. `linger` запускает пользовательский демон при
загрузке и сохраняет его после выхода из сессии. Docker внутри агентской VM не меняется.

После `nh os switch ~/config` полностью выйди из пользовательской сессии и войди
снова: обновятся группы и `DOCKER_HOST`. Проверка: `systemctl --user status docker`
и `docker info` — среди Security Options должен быть `rootless`. Для текущего
терминала сокет можно выбрать явно:

```bash
export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
```

Docker использует стандартный путь `~/.local/share/docker`, но impermanence
отдельно bind-монтирует его из `/var/lib/docker/home/<юзер>/.local/share/docker`.
Физически образы, контейнеры и volumes находятся на существующем датасете
`zroot/docker`, а не на `/persistent`. Датасет монтируется в initrd через
`neededForBoot`; создание пользовательского каталога и его права `0700`
обеспечивает impermanence. Его автоматические ZFS-снапшоты по-прежнему отключены.
Старые rootful-данные в `/var/lib/docker` остаются нетронутыми и автоматически
не мигрируют.

Нативный Docker storage driver `zfs` не поддерживает rootless. Хранилище остаётся
на файловой системе ZFS, но слои больше не являются отдельными ZFS-датасетами.
Docker выбирает поддерживаемый backend автоматически; проверочный запуск
Docker 29.8.1 на `main` использовал containerd snapshotter `overlayfs`.

Обычные `docker` и Compose работают без sudo. По умолчанию нельзя публиковать
хостовые порты ниже 1024: используй, например, `8080:80`. `--privileged` не даёт
root-права на хосте; доступ к устройствам и права non-root пользователей
контейнера на bind mounts требуют отдельной проверки. Ограничения:
[Docker Rootless](https://docs.docker.com/engine/security/rootless/troubleshoot/#known-limitations).

## Синхронизация main ↔ laptop

Nix управляет службой, сетью и исключениями OMP. Устройства и общие
папки добавляются один раз через GUI Syncthing — Device ID в Nix не записываются.
`overrideDevices = false` и `overrideFolders = false` сохраняют эти настройки;
деклараций `settings.devices` и `settings.folders` нет, поэтому rebuild
не перезаписывает участников папок. Для первоначальной настройки используются:

- SSH: `~/.ssh`, включая ключи. Права файлов сохраняются, каталог — `0700`.
- Minecraft: на ПК `/mnt/data/Games/Minecraft/Prism/instances`, на ноутбуке
  `~/.local/share/FreesmLauncher/instances`. Настройки лаунчера не изменяются,
  каталоги не переносятся. В GUI включи Ignore Permissions для этой папки
  на обеих машинах, поскольку исходный диск — NTFS.
- OMP: `~/.omp`. Декларативный `.stignore` содержит разрешённые настройки,
  инструкции и плагины; сессии, история, SQLite-базы и runtime-состояние исключены.

`~/.omp/.stignore` управляется Home Manager: его правила меняются в Nix,
не в GUI Syncthing. Служба ждёт успешной активации Home Manager, поэтому
исключения присутствуют до первого сканирования. `UMask=0077` задаёт закрытые
права при создании; при включённой синхронизации прав Syncthing затем применяет
права источника. Правил tmpfiles и пользовательских скриптов нет.
На `main` служба требует монтирования `/mnt/data`: у диска стоит `nofail`,
поэтому без этой зависимости возможен запуск до появления инстансов.
Локальное обнаружение, без глобального discovery, relay и NAT traversal.
Стандартные порты: TCP/UDP 22000 и UDP 21027. GUI: `http://127.0.0.1:8384`.
После пейринга оба устройства равноправны; удаления распространяются в обе стороны.

Перед сменой устройства закрой Minecraft и дождись завершения синхронизации.
Живые миры нельзя безопасно объединять. Инстансы на NTFS у ПК **не покрываются
ZFS-снапшотами**. Пути Java в существующих инстансах могут требовать настройки
на ноутбуке; Syncthing не переписывает содержимое конфигов.

Syncthing сам создаёт и хранит сертификат, приватный ключ и базу в
`~/.local/state/syncthing`. Каталог уже сохраняется impermanence и не
синхронизируется. Передавать ключи между машинами не нужно.
`services.syncthing.configDir` задан явно: смена `user` сама по себе не меняет
стандартный путь `/var/lib/syncthing/.config/syncthing`, который обычный
пользователь создать не может. База по умолчанию использует тот же `configDir`.

Первичный пейринг:

1. Примени конфиг на обоих устройствах. Syncthing запускается без заранее
   подготовленных ключей; существующая идентичность сохраняется.
2. На ноутбуке открой `http://127.0.0.1:8384` → Actions → Show ID.
3. На ПК открой тот же локальный адрес → Add Remote Device и вставь ID ноутбука.
   На ноутбуке подтверди подключение ПК, сверив его ID через Actions → Show ID.
4. На ПК через Add Folder добавь три каталога из списка выше, выбери Send & Receive
   и отметь ноутбук на вкладке Sharing. Для SSH в Ignore Patterns укажи
   `/{agent,controlmasters,sockets}` и `known_hosts.old`; для Minecraft —
   `(?d){logs,crash-reports,natives,.cache,session.lock}` и Ignore Permissions.
5. На ноутбуке прими приглашения папок и выбери соответствующие локальные пути.
   Folder ID оставь из приглашения. Для Minecraft также включи Ignore Permissions
   и те же исключения; для SSH — те же исключения. Исключения OMP уже созданы Nix.

Дальше настройки устройств, папок и их участников сохраняет Syncthing в своём
локальном состоянии. Повторно редактировать Nix-конфиг для пейринга не нужно.
Приватные ключи самого Syncthing между устройствами не копируются и в публичный Git не попадают.
Проверка: `systemctl status syncthing syncthing-init` и GUI.

## Подпись коммитов GPG

На `main` и `laptop` Home Manager устанавливает GnuPG и gpg-agent с Qt-запросом
пароля, включает подпись коммитов и тегов. Ключ выбирается по email из Git-конфига.
Настройки подписи находятся в `common/home/git.nix` и применяются при включённом
`programs.gpg.enable`. Агентская VM использует эти же настройки и подписывает
через ограниченный сокет хостового gpg-agent; приватные ключи остаются на хосте.
Применение и проверка описаны в `agent/README.md`, раздел «Git и подпись GPG».

После `nh os switch` импортируй приватный ключ через `gpg --import /путь/к/key.asc`
или создай новый с парольной фразой:

```bash
gpg --quick-generate-key 'Spliterash <me@spliterash.ru>' ed25519 sign 2y
gpg --armor --export me@spliterash.ru
```

Публичный ключ добавь в GitHub → Settings → SSH and GPG keys → New GPG key;
email ключа должен быть подтверждён в аккаунте. Пока приватного ключа нет,
подписанные коммиты не создаются. `~/.gnupg` сохраняется в `/persistent` с правами
`0700`; приватный ключ и сертификат отзыва резервируй отдельно, не клади в Git
или Nix store. Проверка подписи последнего коммита: `git verify-commit HEAD`.

## Установка по сети с main (nixos-anywhere) — как реально ставился laptop

`laptop` ставился не локально, а удалённо с `main`: система собирается на
`main`, по LAN на ноут копируется только результат (closure). Ноут при этом
загружен с NixOS live-ISO с доступом по SSH (root, пароль установщика).

Важно: disko **стирает весь SSD ноутбука**, создаёт ESP (2 GiB, `/boot`) и
раздел под ZFS, оставляя около 100 GiB (107,4 GB) незанятыми под Windows.
Первоначальная установка занимала весь диск; уменьшить существующий ZFS
на месте нельзя. Изменение конфига и `nixos-rebuild` сами диск не переразмечают.

Перед стиранием проверь на live-системе, что это именно ноутбук и нужный SSD:
```bash
ssh root@<ip> 'hostname; lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS,MODEL; readlink -f /dev/disk/by-id/nvme-Micron_MTFDHBA512QFD_20432B2E2878'
```

1. С `main` поставь ssh-ключ на ноут и сними реальный hardware-config:
   ```bash
   ssh-copy-id root@<ip>
   ssh root@<ip> 'nixos-generate-config --no-filesystems --show-hardware-config' \
     > laptop/system/hardware-configuration.nix
   ```
2. Собери diskoScript на `main` и скопируй его closure на ноут:
   ```bash
   P=$(nix build .#nixosConfigurations.laptop.config.system.build.diskoScript --print-out-paths --no-link)
   nix copy --to ssh://root@<ip> --no-check-sigs "$P"
   ```
3. Прогони disko на ноуте, **подав пароль шифрования в stdin** (см. грабли).
   В Bash введи пароль интерактивно, не записывая его в историю команд:
   ```bash
   read -r -s -p 'Пароль ZFS (не менее 8 символов): ' PASSPHRASE; printf '\n'
   printf '%s\n%s\n' "$PASSPHRASE" "$PASSPHRASE" | ssh root@<ip> "$P"
   unset PASSPHRASE
   ```
   Диск размечен, пул создан и смонтирован в `/mnt`.
4. Установи систему (сборка на `main`, копия на ноут) и перезагрузи:
   ```bash
   nix run github:nix-community/nixos-anywhere -- --flake .#laptop --phases install,reboot --target-host root@<ip>
   ```

После установки NixOS загрузи установщик Windows в режиме UEFI и выбери
незанятое место в конце диска. Разделы EFI и ZFS не удаляй и не форматируй.
Windows создаст свои разделы в свободном месте; при смене порядка загрузки
верни Linux Boot Manager первым в UEFI. Systemd-boot обнаруживает Windows
Boot Manager на общем ESP. Secure Boot должен оставаться выключенным:
подписанная загрузка NixOS в этом конфиге не настроена.

### Грабли (проверено на практике)

- **Пароль ZFS ≥ 8 символов** — короче ZFS не примет, `zpool create` упадёт.
- **`keylocation=prompt` + nixos-anywhere.** При запуске напрямую из терминала
  актуальный nixos-anywhere выделяет SSH TTY и запускает disko в нём: пароль
  ZFS вводится в терминале запускающего компьютера, не на экране ноутбука.
  Не перенаправляй stdin установщика и не запускай его через пайп. Для
  неинтерактивного запуска остаётся отдельный disko с передачей пароля в stdin
  (шаг 3). Пароль в репозиторий не попадает, `keylocation` остаётся `prompt`.
- **Чистый экспорт пула перед ребутом.** После ручного disko (шаг 3) пул
  остаётся импортированным под hostid live-ISO. При `boot.zfs.forceImportRoot
  = false` установленная система откажется импортировать «чужой» пул и упадёт
  в initrd с ошибкой монтирования zpool. Фаза `reboot` в шаге 4 экспортирует
  пул сама; но если ребутишь **вручную** — сначала:
  ```bash
  umount /mnt/boot        # снять вложенный ESP, иначе пул «busy»
  zpool export zroot
  ```
  Проверить: `zpool import` должен показывать пул как импортируемый по имени
  без предупреждений о hostid и без `-f`.
- **`Failed to install bootloader`.** `extraInstallCommands` в
  `common/system/boot-generations.nix` вызывает `git log` по `programs.nh.flake` —
  в свежей системе репозитория там ещё нет, git падает, и под `set -e` это
  роняло весь установщик загрузчика (вывод git скрыт `2>/dev/null`). Git-вызов
  сделан нефатальным (`|| true`). Загрузке это не мешало (boot-файлы к тому
  моменту уже установлены), но ломало `nixos-install`/`nixos-rebuild`.
- **Firefox: поисковики есть, расширений нет, `ERROR_CORRUPT_FILE`.** URL вида
  `https://addons.mozilla.org/en-US/firefox/downloads/latest/.../latest.xpi`
  может вернуть HTML-страницу проверки с HTTP 200 вместо XPI. В
  `common/home/soft/furryfox/default.nix` используются загрузочные URL без
  `/en-US/`: `https://addons.mozilla.org/firefox/downloads/latest/.../latest.xpi`.
  После применения конфига полностью перезапусти Firefox; профиль удалять не нужно.
- **Sidebery без дополнительной панели кнопок Firefox.** В общем профиле задано
  `sidebar.visibility = "hide-launcher"`: панель кнопок скрыта, сама Sidebery
  остаётся доступной. Настройка действует на обоих хостах и в профиле «Амиго».
  TWP — Translate Web Pages устанавливается общей политикой расширений.

## Что дальше по месту

Хосту `laptop` специально закомментированы модули, включаемые вручную по
необходимости (`laptop/system/default.nix`, `laptop/home/default.nix`) — сейчас
там ничего лишнего не закомментировано, т.к. gaming-стек (docker/wine/steam/
sunshine/xbox/vm) уже общий для всех хостов. Если на ноуте что-то из этого не
нужно — убирай точечно из `common/system/default.nix` или переопределяй в
`laptop/system/default.nix`.

На Lenovo 82EY проверены AMD Renoir (`05:00.0`) и NVIDIA GTX 1650 (`01:00.0`).
Встроенный экран eDP подключён к AMD, HDMI — к NVIDIA. В
`laptop/system/gpu.nix` задан ранний `amdgpu` для Plymouth и PRIME offload
с этими PCI-адресами; запуск приложения на дискретной карте:
`nvidia-offload <команда>`.

Для GTX 1650 выбран закрытый модуль NVIDIA без GSP, включены RTD3 и
сохранение видеопамяти при сне. У открытого модуля RTD3 поддерживается только
на Ampere и новее — см. [ограничения NVIDIA](https://download.nvidia.com/XFree86/Linux-x86_64/595.45.04/README/kernel_open.html).
При замене ноутбука или смене режима GPU в BIOS заново проверь PCI-адреса
и подключение экрана. После установки проверь графический запрос ZFS,
цикл сон/пробуждение и HDMI на железе. NVIDIA может оставаться активной,
пока приложение использует её или к HDMI подключён монитор.
Гибернация не настроена: текущий ZFS-конфиг добавляет `nohibernate`, swap отсутствует.
