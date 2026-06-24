#!/usr/bin/env bash

# Украденно у Владека, показывает снапшоты которые есть для текущей папки и позволяет быстренько посмотреть
zcd() {
  local current_dir
  current_dir=$(pwd)

  # 1. Get the dataset name from the first column of df
  dataset=$(df -P "$current_dir" | awk 'NR==2 {print $1}')

  # Verify it is actually a ZFS dataset
    if ! zfs list "$dataset" >/dev/null 2>&1; then
        echo "Error: Filesystem '$dataset' is not recognized as a ZFS dataset."
        return 1
    fi

  # 2. Check its mountpoint via zfs get
  local zfs_mountroot=$(zfs get -H -o value mountpoint "$dataset")

  # Handle cases where ZFS delegates mounting (e.g., fstab)
  if [[ "$zfs_mountroot" == "legacy" || "$zfs_mountroot" == "none" ]]; then
    zfs_mountroot=$(df -P "$current_dir" | awk 'NR==2 {print $6}')
  fi

  local snap_dir="${zfs_mountroot%/}/.zfs/snapshot"

  if [ ! -d "$snap_dir" ]; then
    echo "Error: No ZFS snapshots found for this dataset at $snap_dir."
    return 1
  fi

  # Calculate the path relative to the mountpoint
  local rel_path="${current_dir#"$mnt_point"}"
  rel_path="${rel_path#/}" # Remove leading slash

  # Select snapshot using fzf
  local selected_snap=$(\command ls -1 "$snap_dir" | fzf --prompt="Select ZFS Snapshot: ")

  if [ -z "$selected_snap" ]; then
    return 0
  fi

  local target_dir="$snap_dir/$selected_snap/$rel_path"

  if [ -d "$target_dir" ]; then
    cd "$target_dir" || return 1
    echo "Moved to snapshot: $selected_snap"
  else
    echo "Error: This directory does not exist in the selected snapshot."
    return 1
  fi
}

# навайбленная фигня чтобы смотреть чё слетит при ребуте
dirty() {
  sudo -v || return 1
  local home_dir="${HOME%/}"
  local list
  list=$(
    sudo zfs diff -F zroot/root@blank 2>/dev/null \
      | awk -F'\t' -v home="$home_dir" '
          function under(path, prefix) {
            return path == prefix || index(path, prefix "/") == 1
          }

          NR==FNR {
            mountpoint = $0
            if (mountpoint == "" || mountpoint == "/" || mountpoint == home) next
            if (mountpoint == "/tmp" || under(mountpoint, home)) {
              skip[mountpoint] = 1
            }
            next
          }

          {
            path = $NF
            if (path == home) next
            if (!under(path, home)) next
            for (mountpoint in skip) {
              if (under(path, mountpoint)) next
            }

            ch  = $1
            col = (ch == "+") ? "32" : (ch == "-") ? "31" : (ch == "M") ? "33" : "35"
            printf "\033[%sm%s\033[0m\t%s\t%s\n", col, ch, $2, path
          }
        ' <(
          printf '/tmp\n'
          findmnt -rn -o TARGET 2>/dev/null
          sudo zfs list -H -o mountpoint -r zroot 2>/dev/null
        ) -
  )

  if [ -z "$list" ]; then
    echo "✔ грязный слой пуст — в $home_dir нет изменений поверх @blank"
    return 0
  fi

  # Неинтерактивный режим: просто список (для пайпов или `dirty -l`).
  if [ "$1" = "-l" ] || [ "$1" = "--list" ] || [ ! -t 1 ]; then
    printf '%s\n' "$list"
    return 0
  fi

  local selected selected_path
  selected=$(
    printf '%s\n' "$list" | fzf \
    --ansi \
    --delimiter='\t' \
    --nth=3 \
    --prompt='dirty> ' \
    --header='zroot/root@blank · enter=cd · q=выход' \
    --preview-window='right,55%,wrap' \
    --preview='
      p={3}
      if sudo test -d "$p"; then
        sudo ls -la --color=always "$p" 2>/dev/null | head -n 300
      elif sudo test -f "$p"; then
        if command -v bat >/dev/null 2>&1; then
          sudo bat --color=always --style=numbers --line-range=:300 "$p" 2>/dev/null
        else
          sudo sed -n "1,300p" "$p" 2>/dev/null
        fi
      elif sudo test -e "$p"; then
        sudo stat "$p" 2>/dev/null
      else
        echo "удалён в живом / (показываю из @blank):"
        sudo sed -n "1,300p" "/.zfs/snapshot/blank/${p#/}" 2>/dev/null || echo "(нет и в снапшоте)"
      fi
    ' \
    --bind='q:abort'
  ) || return 0

  selected_path=$(printf '%s\n' "$selected" | awk -F'\t' '{print $3}')
  [ -n "$selected_path" ] || return 0

  if ! sudo test -d "$selected_path"; then
    selected_path=${selected_path%/*}
  fi

  [ -n "$selected_path" ] || selected_path=/
  cd "$selected_path" || return 1
}
