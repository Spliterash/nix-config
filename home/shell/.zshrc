#? https://github.com/ohmyzsh/ohmyzsh/issues/31#issuecomment-359728582
unsetopt nomatch

#? type aliases breaks shebang
# alias -s ts="bun"
# alias -s py="python"

autoload -Uz select-word-style
select-word-style bash

# home
bindkey "^[[H"    beginning-of-line
#? probably, for WSL (or wt.exe), but works on wezterm too
bindkey "^[OH"    beginning-of-line
# end
bindkey "^[[F"    end-of-line
#? probably, for WSL (or wt.exe), but works on wezterm too
bindkey "^[OF"    end-of-line

# page up/down
bindkey "^[[5~"   beginning-of-history
bindkey "^[[6~"   end-of-history

# alt + left/right
bindkey "^[[1;3D" backward-word
bindkey "^[[1;3C" forward-word
# ctrl + left/right
bindkey "^[[1;5D" backward-word
bindkey "^[[1;5C" forward-word

# delete
bindkey "^[[3~"   delete-char
# alt + backspace
bindkey "^[^H"    backward-kill-word
# alt + delete
bindkey "^[[3;3~" delete-word
# ctrl + backspace
bindkey "^H"      backward-kill-word
# ctrl + delete
bindkey "^[[3;5~" delete-word

#? https://wiki.archlinux.org/title/Zsh#Shortcut_to_exit_shell_on_partial_command_line
exit_zsh() { exit; }
zle -N exit_zsh
bindkey '^D' exit_zsh

#? https://www.reddit.com/r/zsh/comments/eo80b6/comment/feaaib8/
function set-term-title-precmd() {
    emulate -L zsh
    print -rn -- $'\e]0;'${(V%):-'%~'}$'\a' >$TTY
}
function set-term-title-preexec() {
    emulate -L zsh
    print -rn -- $'\e]0;'${(V)1}$'\a' >$TTY
}
autoload -Uz add-zsh-hook
add-zsh-hook preexec set-term-title-preexec
add-zsh-hook precmd set-term-title-precmd
set-term-title-precmd



# Приколюхи для удобного монтирования серваков и редача файлов в vscode
SSHFS_BASE=$HOME/mnt/server

#? Мультиплексирование SSH: автокомплит дёргает ssh на каждый таб, без этого
#? каждый раз новое рукопожатие. ControlMaster держит один сокет, ControlPersist
#? оставляет мастер живым ещё N секунд после последнего соединения.
SSH_MUX_DIR="${XDG_RUNTIME_DIR:-/tmp}/ssh-mux"
ssh_mux() {
    mkdir -p "$SSH_MUX_DIR" 2>/dev/null
    ssh -o ControlMaster=auto -o ControlPath="$SSH_MUX_DIR/%C" -o ControlPersist=60 "$@"
}

#? Список хостов из ~/.ssh/config (без wildcard-паттернов) — общий для
#? автокомплита sshe и обычного ssh.
_ssh_config_hosts() {
    awk '/^[Hh]ost / {for(i=2;i<=NF;i++) print $i}' ~/.ssh/config 2>/dev/null | grep -v '[*?]'
}

sshe() {
    local host=$1 subpath=$2
    local mnt=$SSHFS_BASE/$host
    mkdir -p "$mnt" || return 1
    if ! mount | grep -q " $mnt "; then
        sshfs "$host:/" "$mnt" -o reconnect,ServerAliveInterval=15 \
            || { echo "sshfs failed"; return 1; }
    fi
    if [[ -n $subpath ]]; then
        code "$mnt$subpath"
    else
        dolphin "$mnt" &>/dev/null &
    fi
}

_sshe() {
    if (( CURRENT == 2 )); then
        local -a hosts
        hosts=(${(f)"$(_ssh_config_hosts)"})
        _describe 'host' hosts
    elif (( CURRENT == 3 )); then
        local host=${words[2]}
        local cur=${words[3]}
        local dir
        if [[ $cur == */* ]]; then
            dir=${cur%/*}/
        else
            dir=/
        fi
        local -a entries
        entries=(${(f)"$(ssh_mux -o BatchMode=yes "$host" "ls -1p ${dir} 2>/dev/null" 2>/dev/null)"})
        local -a dirs files
        local e
        for e in $entries; do
            if [[ $e == */ ]]; then
                dirs+=("${dir}${e}")
            else
                files+=("${dir}${e}")
            fi
        done
        compadd -S '' -- $dirs
        compadd -- $files
    fi
}
compdef _sshe sshe

sshc() {
    local mnt found=0
    for mnt in "$SSHFS_BASE"/*(N/); do
        if mount | grep -q " $mnt .*fuse\.sshfs"; then
            if fusermount -u "$mnt" 2>/dev/null || umount "$mnt" 2>/dev/null; then
                echo "unmounted: $mnt"
                rmdir "$mnt" 2>/dev/null
                found=1
            else
                echo "failed to unmount: $mnt (открыт в приложении?)"
            fi
        elif mount | grep -q " $mnt "; then
            echo "skip: $mnt (не sshfs, не трогаю)"
        else
            rmdir "$mnt" 2>/dev/null
        fi
    done
    (( found )) || echo "Нечего размонтировать"
}

#? Чиним автокомплит хостов для обычного ssh/scp/sftp: по умолчанию zsh тащит
#? мусор из /etc/hosts и ~/.ssh/known_hosts. Берём только хосты из ~/.ssh/config.
#? zstyle -e вычисляет список на каждый таб, так что правки конфига видны сразу.
zstyle -e ':completion:*:(ssh|scp|sftp|slogin):*' hosts 'reply=(${(f)"$(_ssh_config_hosts)"})'