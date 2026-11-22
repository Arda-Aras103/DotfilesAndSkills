#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[1/3] Installing btop, fzf, zoxide, fd-find, ripgrep, gdu, and procs..."
sudo dnf install -y btop fzf zoxide fd-find ripgrep gdu procs

echo "[2/3] Configuring btop Tokyo Night theme..."
mkdir -p "$HOME/.config/btop/themes"
cp -f "$ROOT_DIR/configs/btop/tokyo-night.theme" "$HOME/.config/btop/themes/tokyo-night.theme"

BTOP_CONF="$HOME/.config/btop/btop.conf"
if [[ -f "$BTOP_CONF" && ! -f "$BTOP_CONF.rice.bak" ]]; then
  cp -f "$BTOP_CONF" "$BTOP_CONF.rice.bak"
fi

python3 - <<'EOF'
import os
import re

path = os.path.expanduser("~/.config/btop/btop.conf")
if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
else:
    text = ""

def set_btop_opt(src, key, val):
    pat = re.compile(rf"^{re.escape(key)}\s*=.*$", re.MULTILINE)
    line = f"{key} = {val}"
    if pat.search(src):
        return pat.sub(line, src, count=1)
    if src and not src.endswith("\n"):
        src += "\n"
    return src + line + "\n"

text = set_btop_opt(text, "color_theme", '"tokyo-night"')
text = set_btop_opt(text, "theme_background", "False")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
EOF

echo "[3/3] Adding fzf Tokyo Night, zoxide (cd), smart find/grep/du/kill to ~/.bashrc..."
if [[ -f "$HOME/.bashrc" && ! -f "$HOME/.bashrc.tui.bak" ]]; then
  cp -f "$HOME/.bashrc" "$HOME/.bashrc.tui.bak"
fi

touch "$HOME/.bashrc"
sed -i '/^# >>> rice-tui >>>$/,/^# <<< rice-tui <<<$/d' "$HOME/.bashrc"
cat <<'EOF' >> "$HOME/.bashrc"

# >>> rice-tui >>>
export FZF_DEFAULT_OPTS="--color=bg+:#283457,bg:#1a1b26,spinner:#9ece6a,hl:#7aa2f7,fg:#c0caf5,header:#7aa2f7,info:#7dcfff,pointer:#7dcfff,marker:#9ece6a,fg+:#c0caf5,prompt:#7aa2f7,hl+:#7dcfff --border=rounded --height=45% --layout=reverse"

if command -v zoxide >/dev/null 2>&1; then
  export _ZO_FZF_OPTS="$FZF_DEFAULT_OPTS --preview 'eza -la --color=always {2..} 2>/dev/null || ls -la {2..}'"
  eval "$(zoxide init bash --cmd cd)"
fi

find() {
  if [[ $# -eq 0 && -t 0 && -t 1 ]] && command -v fzf >/dev/null 2>&1; then
    local out key sel
    if command -v fd >/dev/null 2>&1; then
      out="$(fd --hidden --follow --exclude .git --exclude node_modules --exclude target 2>/dev/null | fzf --exact --tiebreak=end,length --expect=ctrl-p --header='Enter: zed/cd | Ctrl-P: print path' --preview 'if [ -d {} ]; then eza -la --color=always {} 2>/dev/null || ls -la {}; else bat --color=always --style=numbers --line-range :120 {} 2>/dev/null || head -n 120 {}; fi' || true)"
    else
      out="$(command find . -mindepth 1 \( -name .git -o -name node_modules -o -name target \) -prune -o -print 2>/dev/null | sed 's|^\./||' | fzf --exact --tiebreak=end,length --expect=ctrl-p --header='Enter: zed/cd | Ctrl-P: print path' --preview 'if [ -d {} ]; then eza -la --color=always {} 2>/dev/null || ls -la {}; else bat --color=always --style=numbers --line-range :120 {} 2>/dev/null || head -n 120 {}; fi' || true)"
    fi
    key="$(head -n1 <<< "$out")"
    sel="$(sed -n '2p' <<< "$out")"
    [[ -z "$sel" ]] && return 0
    if [[ "$key" == "ctrl-p" ]]; then
      printf '%s\n' "$sel"
    elif [[ -d "$sel" ]]; then
      builtin cd -- "$sel"
    elif command -v zed >/dev/null 2>&1; then
      zed "$sel"
    else
      printf '%s\n' "$sel"
    fi
  else
    command find "$@"
  fi
}

unalias grep 2>/dev/null || true
grep() {
  if [[ $# -eq 0 && -t 0 && -t 1 ]] && command -v rg >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
    local out key sel file line
    out="$(rg --color=always --line-number --no-heading --smart-case "" 2>/dev/null \
      | fzf --ansi --delimiter : --expect=ctrl-p --header='Enter: zed file:line | Ctrl-P: print' \
        --preview 'bat --color=always --style=numbers --highlight-line {2} {1} 2>/dev/null || head -n 120 {1}' \
        --preview-window '+{2}/2' || true)"
    key="$(head -n1 <<< "$out")"
    sel="$(sed -n '2p' <<< "$out")"
    [[ -z "$sel" ]] && return 0
    if [[ "$key" == "ctrl-p" ]] || ! command -v zed >/dev/null 2>&1; then
      printf '%s\n' "$sel"
    else
      file="${sel%%:*}"
      line="${sel#*:}"
      line="${line%%:*}"
      zed "${file}:${line}"
    fi
  else
    command grep --color=auto "$@"
  fi
}

du() {
  if [[ $# -eq 0 && -t 0 && -t 1 ]] && command -v gdu >/dev/null 2>&1; then
    gdu
  else
    command du "$@"
  fi
}

kill() {
  if [[ $# -eq 0 && -t 0 && -t 1 ]] && command -v fzf >/dev/null 2>&1; then
    local pids pid
    pids="$(ps -u "${USER:-$(id -un)}" -o pid=,pcpu=,pmem=,comm=,args= --sort=-pcpu | fzf -m --header='Select process(es) to kill (Tab: multi-select)' | awk '{print $1}' || true)"
    while IFS= read -r pid; do
      [[ -n "$pid" ]] && builtin kill "$pid"
    done <<< "$pids"
  else
    builtin kill "$@"
  fi
}

ps() {
  if [[ $# -eq 0 && -t 1 ]] && command -v procs >/dev/null 2>&1; then
    procs
  else
    command ps "$@"
  fi
}

systemctl() {
  if [[ $# -eq 0 && -t 0 && -t 1 ]] && command -v fzf >/dev/null 2>&1; then
    local out key unit
    out="$(command systemctl list-units --type=service --all --no-legend --no-pager 2>/dev/null \
      | sed 's/^[[:space:]●]*//' \
      | fzf --expect=ctrl-l,ctrl-r --header='Enter: status | Ctrl-L: logs | Ctrl-R: restart' --preview 'SYSTEMD_COLORS=1 systemctl status {1} --no-pager 2>/dev/null' || true)"
    key="$(head -n1 <<< "$out")"
    unit="$(sed -n '2p' <<< "$out" | awk '{print $1}')"
    [[ -z "$unit" ]] && return 0
    case "$key" in
      ctrl-l) journalctl -u "$unit" -n 50 --no-pager ;;
      ctrl-r) sudo systemctl restart "$unit" && command systemctl status "$unit" --no-pager ;;
      *)      command systemctl status "$unit" ;;
    esac
  else
    command systemctl "$@"
  fi
}

git() {
  if [[ $# -eq 1 && -t 0 && -t 1 ]] && command -v fzf >/dev/null 2>&1; then
    case "$1" in
      log)
        local out key hash
        out="$(command git log --oneline --decorate --color=always 2>/dev/null \
          | fzf --ansi --no-sort --expect=ctrl-p --header='Enter: show commit | Ctrl-P: print hash' \
            --preview 'git show --color=always {1} | (delta --paging=never 2>/dev/null || cat)' || true)"
        key="$(head -n1 <<< "$out")"
        hash="$(sed -n '2p' <<< "$out" | awk '{print $1}')"
        [[ -z "$hash" ]] && return 0
        if [[ "$key" == "ctrl-p" ]]; then
          printf '%s\n' "$hash"
        else
          command git show "$hash"
        fi
        return
        ;;
      switch|checkout)
        local branch
        branch="$(command git branch --all --color=never 2>/dev/null \
          | sed 's/^[* ]*//' | command grep -v -- '->' \
          | fzf --header='Enter: switch branch' \
            --preview 'git log --oneline --decorate --color=always -n 20 {} 2>/dev/null' || true)"
        [[ -z "$branch" ]] && return 0
        command git "$1" "${branch#remotes/origin/}"
        return
        ;;
    esac
  fi
  command git "$@"
}

docker() {
  if [[ $# -eq 1 && -t 0 && -t 1 ]] && command -v fzf >/dev/null 2>&1; then
    case "$1" in
      logs)
        local cid
        cid="$(command docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null \
          | fzf --header='Enter: follow logs' \
            --preview 'docker logs --tail 40 {1} 2>&1' \
          | awk '{print $1}' || true)"
        [[ -z "$cid" ]] && return 0
        command docker logs -f "$cid"
        return
        ;;
      exec)
        local cid
        cid="$(command docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null \
          | fzf --header='Enter: shell into container' \
            --preview 'docker inspect --format "Image: {{.Config.Image}}\nState: {{.State.Status}}\nPorts: {{.NetworkSettings.Ports}}" {1} 2>/dev/null' \
          | awk '{print $1}' || true)"
        [[ -z "$cid" ]] && return 0
        command docker exec -it "$cid" sh -c 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'
        return
        ;;
    esac
  fi
  command docker "$@"
}
# <<< rice-tui <<<
EOF

echo "Done. To activate: source ~/.bashrc"
echo "(cd: zoxide | find/grep: fzf+zed | du: gdu | ps: procs | kill/systemctl/git/docker: fzf | Ctrl+R: Atuin)"
