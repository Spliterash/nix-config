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

_ssh_config_hosts() {
    grep -E '^Host ' ~/.ssh/config | awk '{print $2}'
}

# ssh (m)ount
sshm() {
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

_sshm() {
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
compdef _sshm sshm

# ssh (u)nmount
sshu() {
    local mnt found=0
    for mnt in "$SSHFS_BASE"/*(N/); do
        if mount | grep -q " $mnt .*fuse\.sshfs"; then
            if fusermount -u "$mnt" 2>/dev/null || umount "$mnt" 2>/dev/null; then
                echo "unmounted: $mnt"
                rmdir "$mnt" 2>/dev/null
            else
                echo "failed to unmount: $mnt (opened in app?)"
            fi
            found=1
        elif mount | grep -q " $mnt "; then
            echo "skip: $mnt (не sshfs, не трогаю)"
        else
            rmdir "$mnt" 2>/dev/null
        fi
    done
    (( found )) || echo "Nothing to unmount"
}
# ssh (c)onnect
sshc() {
    ssh "$@"
}
_sshc() {
    local -a hosts
    hosts=(${(f)"$(_ssh_config_hosts)"})
    _describe 'host' hosts
}

compdef _sshc sshc

# ssh (i)nit — завести новый сервер «под ключ»:
#?   sshi user@ip <name> [key]
#?   1) копирует публичный ключ на сервер (ssh-copy-id, спросит пароль сервера),
#?   2) дописывает Host в ~/.ssh/config,
#?   3) опционально отключает парольный вход на сервере (спросит подтверждение).
#? key — имя ключа в ~/.ssh (по умолчанию id_rsa).
sshi() {
    emulate -L zsh
    local target=$1 name=$2 key=${3:-id_rsa}
    if [[ -z $target || -z $name ]]; then
        echo "usage: sshi user@ip <name> [key]" >&2
        return 1
    fi
    local user=${target%@*} ip=${target##*@}
    if [[ $target != *@* || -z $user || -z $ip ]]; then
        echo "sshi: первый аргумент должен быть в формате user@ip" >&2
        return 1
    fi

    local priv="$HOME/.ssh/$key" pub="$HOME/.ssh/$key.pub"
    if [[ ! -f $priv || ! -f $pub ]]; then
        echo "sshi: нет ключа $priv(.pub). Создай: ssh-keygen -t ed25519 -f $priv" >&2
        return 1
    fi

    local cfg="$HOME/.ssh/config"
    [[ -d "$HOME/.ssh" ]] || { mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"; }
    [[ -f $cfg ]] || { touch "$cfg" && chmod 600 "$cfg"; }
    if awk -v n="$name" '
        tolower($1)=="host" { for (i=2;i<=NF;i++) if ($i==n) { found=1; exit } }
        END { exit !found }
    ' "$cfg"; then
        echo "sshi: Host '$name' уже есть в $cfg — отменяю, чтобы не плодить дубли" >&2
        return 1
    fi

    echo ":: 1/3 копирую ключ $key.pub на $target (введи пароль сервера)"
    ssh-copy-id -i "$pub" "$target" || { echo "sshi: ssh-copy-id не сработал" >&2; return 1; }

    echo ":: 2/3 пишу Host '$name' в $cfg"
    cat >> "$cfg" <<EOF

Host $name
    HostName $ip
    User $user
    IdentityFile ~/.ssh/$key
    IdentitiesOnly yes
EOF

    echo ":: 3/3 Отключение парольного входа на сервере (опционально)"
    local ans
    read "ans?Отключить парольный вход на '$name'? Убедись, что заходишь по ключу! [y/N] "
    if [[ ${ans:l} == y* ]]; then
        if ssh -t "$name" "echo 'PasswordAuthentication no' | sudo tee /etc/ssh/sshd_config.d/99-disable-password.conf && sudo service ssh restart"; then
            echo ":: парольный вход отключён"
        else
            echo "sshi: не удалось отключить пароль" >&2
            return 1
        fi
    else
        echo ":: пропускаю, пароль оставлен включённым"
    fi
    echo ":: готово → ssh $name"
}





if hash yazi &> /dev/null; then
  function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
  }
fi