# ~/.bashrc: executed by bash(1) for non-login shells.

# Exit early when not interactive
case $- in
    *i*) ;;
    *) return ;;
esac

# Source global definitions (Fedora standard)
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

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
path_prepend "$HOME/.keploy/bin"
export PATH

# ---------------------------------------------------------------------------
# Less / lesspipe
# ---------------------------------------------------------------------------
if [ -x /usr/bin/lesspipe.sh ]; then
    eval "$(SHELL=/bin/sh /usr/bin/lesspipe.sh)"
elif [ -x /usr/bin/lesspipe ]; then
    eval "$(SHELL=/bin/sh lesspipe)"
fi

# ---------------------------------------------------------------------------
# Prompt (fallback when starship is not installed)
# ---------------------------------------------------------------------------
color_prompt=
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes ;;
esac

if [ "$color_prompt" = yes ]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\u@\h:\w\$ '
fi

case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;\u@\h: \w\a\]$PS1"
        ;;
esac
unset color_prompt

# ---------------------------------------------------------------------------
# Colors for grep / dircolors
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
alias cr="printf '\033[2J\033[3J\033[H'"
alias ..="cd .."
alias ...="cd ../.."
alias py="python3"
alias watch-live='watch -n 1 ls -lh'

# ---------------------------------------------------------------------------
# System (Fedora / dnf)
# ---------------------------------------------------------------------------
alias upgrade="sudo dnf upgrade --refresh -y && flatpak update -y && sudo dnf autoremove -y"
alias ports="ss -tulanp"
alias mem="free -m -h"
alias lstk="npx -y @localstack/lstk"

# Long-running command notification: sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history | tail -n1 | sed -e "s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//")"'

# ---------------------------------------------------------------------------
# Config editing
# ---------------------------------------------------------------------------
alias opbash='zed ~/.bashrc'
alias rebash='source ~/.bashrc'

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

# Ensure trailing newline and fail cleanly so Starship/Readline prompt never corrupts
unalias myip 2>/dev/null
myip() {
    local ip
    ip="$(curl -fsS --max-time 5 https://ifconfig.me)" || return 1
    printf '%s\n' "$ip"
}

# Extract any common archive format
extract() {
    if [ $# -eq 0 ] || [ ! -f "$1" ]; then
        echo "'${1:-}' is not a valid file"
        return 1
    fi
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.tar.xz|*.txz)   tar xJf "$1" ;;
        *.tar.zst|*.tzst) tar --zstd -xf "$1" ;;
        *.tar)            tar xf "$1" ;;
        *.bz2)            bunzip2 "$1" ;;
        *.gz)             gunzip "$1" ;;
        *.xz)             unxz "$1" ;;
        *.zst)            unzstd "$1" ;;
        *.rar)            unrar x "$1" ;;
        *.zip)            unzip "$1" ;;
        *.Z)              uncompress "$1" ;;
        *.7z)             7z x "$1" ;;
        *)                echo "'$1' can't be extracted via extract()"; return 1 ;;
    esac
}

# Query cheat.sh
cheat() {
    if [ $# -eq 0 ]; then
        echo "Usage: cheat <topic>" >&2
        return 1
    fi
    curl -fsS "https://cheat.sh/${*// /+}"
}

# pv: small single files are printed with raw cat, larger ones go through pv.
pv() {
    if [[ $# -eq 1 && -f "$1" ]]; then
        local size
        size=$(stat -c%s -- "$1")
        if (( size < 100*1024*1024 )); then
            command cat -- "$1"
            return
        fi
    fi
    command pv "$@"
}

agy() {
  local n="${1:-1}"
  local name="agy"
  [ "$n" != "1" ] && name="agy-$n"

  if docker ps --format '{{.Names}}' | grep -qx "$name"; then
    echo "$name zaten çalışıyor. Başka bir numara deneyin veya o sekmeye geçin."
    return 1
  elif docker ps -a --format '{{.Names}}' | grep -qx "$name"; then
    docker start -ai "$name"
  else
    local env_args=()
    [ -f "$HOME/agy-docker/keys.env" ] && env_args=(--env-file "$HOME/agy-docker/keys.env")
    docker run -it --name "$name" \
      "${env_args[@]}" \
      -v "$HOME/agy-docker/workspace:/workspace:Z" \
      -v "$HOME/agy-docker/shared-home/.gemini:/root/.gemini:Z" \
      -w /workspace \
      fedora-agy:latest
  fi
}

# ---------------------------------------------------------------------------
# Shell Prompt, History & Rice Tools
# ---------------------------------------------------------------------------
[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
command -v atuin >/dev/null 2>&1 && eval "$(atuin init bash)"
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"

alias fastfetch="$HOME/.config/fastfetch/fastfetch-rotate.sh"

# >>> rice-cli >>>
export EZA_COLORS="reset:di=1;34:ln=36:ex=32:da=2;37:ur=90:uw=90:ux=90:gr=90:gw=90:gx=90:tr=90:tw=90:tx=90"
alias ls='eza --group-directories-first'
alias ll='eza -la --group-directories-first --git'
alias la='eza -a --group-directories-first'
alias lt='eza --tree --level=2'
alias cat='bat --paging=never'
# <<< rice-cli <<<

[ "$TERM" = "xterm-kitty" ] && alias ssh="kitten ssh"

# >>> rice-yazi >>>
y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
# <<< rice-yazi <<<

# >>> rice-tui >>>
export FZF_DEFAULT_OPTS="--color=bg+:#283457,bg:#1a1b26,spinner:#9ece6a,hl:#7aa2f7,fg:#c0caf5,header:#7aa2f7,info:#7dcfff,pointer:#7dcfff,marker:#9ece6a,fg+:#c0caf5,prompt:#7aa2f7,hl+:#7dcfff --border=rounded --height=45% --layout=reverse"
find() {
  if [[ $# -eq 0 && -t 0 && -t 1 ]] && command -v fzf >/dev/null 2>&1; then
    local sel
    sel="$(command find . -mindepth 1 \( -name .git -o -name node_modules -o -name target \) -prune -o -print 2>/dev/null | sed 's|^\./||' | fzf --exact --tiebreak=end,length --preview 'if [ -d {} ]; then eza -la --color=always {} 2>/dev/null || ls -la {}; else bat --color=always --style=numbers --line-range :120 {} 2>/dev/null || head -n 120 {}; fi' || true)"
    if [[ -d "$sel" ]]; then
      builtin cd -- "$sel"
    elif [[ -n "$sel" ]]; then
      printf '%s\n' "$sel"
    fi
  else
    command find "$@"
  fi
}
# <<< rice-tui <<<
