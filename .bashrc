# ~/.bashrc: executed by bash(1) for non-login shells.

# Exit early when not interactive
case $- in
    *i*) ;;
    *) return ;;
esac

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTCONTROL=ignoreboth      # no duplicates, no lines starting with a space
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend         # append instead of overwrite
shopt -s checkwinsize       # update LINES/COLUMNS after each command

# ---------------------------------------------------------------------------
# PATH (single place, no duplicates)
# ---------------------------------------------------------------------------
path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.local/go/bin"
path_prepend "$HOME/go/bin"
export PATH

# ---------------------------------------------------------------------------
# Less / lesspipe
# ---------------------------------------------------------------------------
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

color_prompt=
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes ;;
esac

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

# Window title for xterm-like terminals
case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
esac
unset color_prompt

# ---------------------------------------------------------------------------
# Colors and aliases for ls / grep
# ---------------------------------------------------------------------------
if [ -x /usr/bin/dircolors ]; then
    if [ -r ~/.dircolors ]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi
alias ls='ls --color=auto'

# ---------------------------------------------------------------------------
# Local aliases file
# ---------------------------------------------------------------------------
[ -f ~/.bash_aliases ] && . ~/.bash_aliases

# ---------------------------------------------------------------------------
# Programmable completion
# ---------------------------------------------------------------------------
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# ---------------------------------------------------------------------------
# Navigation and listing
# ---------------------------------------------------------------------------
alias cr="clear"
alias ..="cd .."
alias ...="cd ../.."
alias ll="ls -lah"
alias l="ls -CF"
alias py="python3"
alias watch-live='watch -n 1 ls -lh'

# ---------------------------------------------------------------------------
# System
# ---------------------------------------------------------------------------
alias update="sudo apt update && sudo apt upgrade -y"
alias autoremove="sudo apt autoremove -y"
alias ports="ss -tulanp"
alias mem="free -m -h"
alias myip="curl -s ifconfig.me"    # Dış IP adresini gösterir

# Long-running command notification: sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history | tail -n1 | sed -e "s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//")"'

# ---------------------------------------------------------------------------
# Config editing
# ---------------------------------------------------------------------------
alias opbash='${EDITOR:-nano} ~/.bashrc'
alias rebash='source ~/.bashrc'

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

# Extract any common archive format
extract() {
    if [ ! -f "$1" ]; then
        echo "'$1' is not a valid file"
        return 1
    fi
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.tar)            tar xf "$1" ;;
        *.bz2)            bunzip2 "$1" ;;
        *.gz)             gunzip "$1" ;;
        *.rar)            unrar x "$1" ;;
        *.zip)            unzip "$1" ;;
        *.Z)              uncompress "$1" ;;
        *.7z)             7z x "$1" ;;
        *)                echo "'$1' can't be extracted via extract()"; return 1 ;;
    esac
}

# Query cheat.sh
cheat() {
    curl -s "https://cheat.sh/$1"
}

# pv: small single files are printed with cat, larger ones go through pv.
# Note: for small files this skips the progress bar on purpose.
pv() {
    if [[ $# -eq 1 && -f "$1" ]]; then
        local size
        size=$(stat -c%s -- "$1")
        if (( size < 100*1024*1024 )); then
            cat -- "$1"
            return
        fi
    fi
    command pv "$@"
}

# ---------------------------------------------------------------------------
# Optional tools (loaded only when installed)
# ---------------------------------------------------------------------------

# Atuin shell history
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init bash)"
fi

# Debian convenience aliases for renamed packages
command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1 && alias fd='fdfind'
command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1 && alias bat='batcat'
