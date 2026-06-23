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