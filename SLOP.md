# Установка

Флейк на несколько хостов. Каждый хост живёт в `hosts/<имя>/` и собирается как
`nixosConfigurations.<имя>` (сейчас есть `main` и `laptop`).

```
hosts/
  common.nix        — общее для всех хостов (пакеты, юзер, общие модули)
  main/              — десктоп (AMD GPU, установлен и работает)
  laptop/            — ноут (NVIDIA, ещё не установлен — см. ниже)
modules/             — системные NixOS-модули
home/                — home-manager конфиг (общий + per-soft файлы)
```

Разметка диска (GPT, EFI-раздел, раздел под ZFS) — единственный ручной шаг:
диск общий с Windows (двачбут), и disko не может размечать автоматически, не
зная где чужие разделы. Всё остальное — пул, датасеты, шифрование, снапшот
для имперманенса, монтирование под `/mnt` — делает готовый скрипт disko
одной командой (см. пункт 4), руками ничего создавать/монтировать/grep'ать
не нужно.

Исключение — `laptop`: он ставился на **весь диск** (NixOS-only, без Windows),
поэтому его `disk-config.nix` описывает полный layout (ESP 2 ГБ + раздел под
ZFS) и disko размечает *и* монтирует ESP сам — ручная разметка (§2) и ручное
монтирование ESP (§4) для него не нужны. Ставился он удалённо по сети с `main`
через `nixos-anywhere` — см. отдельный раздел ниже.

## 0. Что нужно знать заранее

- Каждый хост — отдельный `networking.hostId` (обязателен для ZFS) и
  `networking.hostName`. Уже прописаны в `hosts/<имя>/modules.nix`.
- Имперманенс: корень (`/`) откатывается к чистому ZFS-снапшоту
  `zroot/root@blank` при каждой загрузке (см. `impermanence.nix`). Всё, что
  должно пережить перезагрузку, лежит в `/persistent` (и `/shit` — для
  кэшей типа `.cache`/`.gradle`/`.npm`, которые не обязательно снапшотить).
  Снапшот создаётся автоматически при создании пула (`postCreateHook` в
  `disk-config.nix`) — руками ничего делать не нужно.
- Шифрование пула (native ZFS encryption, `keylocation=prompt`) — только у
  `laptop`. `main` без шифрования. Смотри сам `disk-config.nix` нужного
  хоста, а не эту инструкцию, если не уверен. Файла с ключом нигде нет —
  пароль спрашивается интерактивно в терминале при создании пула (пункт 4)
  и на каждой загрузке.
- Если рядом стоит Windows на том же диске — сначала ставь/оставь Windows,
  EFI-раздел общий на оба ОС.

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
`/tmp/config` — финальное место `/home/<юзер>/config` появится само после
установки (`programs.nh.flake` в `hosts/common.nix` на это рассчитан).

Для **нового** хоста (по образцу `hosts/laptop/`, если ставишь именно
ноут — эти правки уже сделаны, просто проверь):

- `hosts/<имя>/disk-config.nix` — замени `REPLACE_ME_AT_INSTALL` на реальный
  `/dev/disk/by-id/...` раздела под ZFS (без `-partN`, просто путь родителя,
  как в `hosts/main/disk-config.nix`, либо сразу с `-partN`, если раздел уже
  существует — смотри на `content.type = "gpt"` в файле, определяет, ждёт
  ли disko целый диск или готовый раздел).
- `networking.hostId` в `hosts/<имя>/modules.nix` — уже задан уникально,
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
`hosts/<имя>/hardware-configuration.nix`, заменив там заглушку.

Дальше:

```bash
cd /path/to/config   # где лежит flake.nix
sudo nixos-install --flake .#<имя> --root /mnt
```

Пароль пользователя уже задан в `hosts/common.nix` (`hashedPassword`) — новый
вводить не нужно, если не хочешь сменить.

## 6. Первая загрузка

Перезагрузись, убери флешку. Автологин в Plasma включён
(`modules/desktop-environment.nix`) — сразу должен появиться рабочий стол.

Дальше конфиг живёт по пути из `programs.nh.flake`
(`/home/<юзер>/config`) — склонируй репозиторий именно туда, чтобы работали
`nh os switch`/`nh os build` без флагов.

## Установка по сети с main (nixos-anywhere) — как реально ставился laptop

`laptop` ставился не локально, а удалённо с `main`: система собирается на
`main`, по LAN на ноут копируется только результат (closure). Ноут при этом
загружен с NixOS live-ISO с доступом по SSH (root, пароль установщика).

Важно: `hosts/laptop/disk-config.nix` описывает **весь диск** — ESP (2 ГБ,
`/boot`) и раздел под ZFS создаёт сам disko. Ручная разметка и монтирование
ESP не нужны.

1. С `main` поставь ssh-ключ на ноут и сними реальный hardware-config:
   ```bash
   ssh-copy-id root@<ip>
   ssh root@<ip> 'nixos-generate-config --no-filesystems --show-hardware-config' \
     > hosts/laptop/hardware-configuration.nix
   ```
2. Собери diskoScript на `main` и скопируй его closure на ноут:
   ```bash
   P=$(nix build .#nixosConfigurations.laptop.config.system.build.diskoScript --print-out-paths --no-link)
   nix copy --to ssh://root@<ip> --no-check-sigs "$P"
   ```
3. Прогони disko на ноуте, **подав пароль шифрования в stdin** (см. грабли):
   ```bash
   printf '%s\n%s\n' 'PASSPHRASE' 'PASSPHRASE' | ssh root@<ip> "$P"
   ```
   Диск размечен, пул создан и смонтирован в `/mnt`.
4. Установи систему (сборка на `main`, копия на ноут) и перезагрузи:
   ```bash
   nixos-anywhere --flake .#laptop --phases install,reboot --target-host root@<ip>
   ```

### Грабли (проверено на практике)

- **Пароль ZFS ≥ 8 символов** — короче ZFS не примет, `zpool create` упадёт.
- **`keylocation=prompt` + nixos-anywhere.** Штатная disko-фаза nixos-anywhere
  не умеет неинтерактивно ввести passphrase (виснет на prompt), поэтому disko
  запускается вручную (шаг 3). При непривязанном к tty stdin ZFS читает пароль
  прямо из stdin — обычный пайп, без `-t`/`expect`. Пароль в репозиторий не
  попадает, `keylocation` остаётся честным `prompt`.
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
  `modules/boot-generations.nix` вызывает `git log` по `programs.nh.flake` —
  в свежей системе репозитория там ещё нет, git падает, и под `set -e` это
  роняло весь установщик загрузчика (вывод git скрыт `2>/dev/null`). Git-вызов
  сделан нефатальным (`|| true`). Загрузке это не мешало (boot-файлы к тому
  моменту уже установлены), но ломало `nixos-install`/`nixos-rebuild`.

## Что дальше по месту

Хосту `laptop` специально закомментированы модули, включаемые вручную по
необходимости (`hosts/laptop/modules.nix`, `hosts/laptop/home.nix`) — сейчас
там ничего лишнего не закомментировано, т.к. gaming-стек (docker/wine/steam/
sunshine/xbox/vm) уже общий для всех хостов. Если на ноуте что-то из этого не
нужно — убирай точечно из `hosts/common.nix` или переопределяй в
`hosts/laptop/modules.nix`.

Если у ноута NVIDIA Optimus (два GPU) — донастрой `hardware.nvidia.prime` в
`modules/gpu/nvidia.nix` с реальными bus id (`lspci | grep -E "VGA|3D"`), это
не входит в базовую заглушку.
