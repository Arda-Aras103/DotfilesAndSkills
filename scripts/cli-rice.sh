#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Installing eza, bat, git-delta, and duf..."
if ! sudo dnf install -y eza bat git-delta duf 2>/dev/null; then
  sudo dnf install -y bat git-delta duf
  sudo dnf copr enable -y alternateved/eza
  sudo dnf install -y eza
fi

echo "[2/4] Writing bat config (clean line numbers, terminal color adaptive)..."
mkdir -p "$HOME/.config/bat"
cat <<'EOF' > "$HOME/.config/bat/config"
--theme="ansi"
--style="numbers"
EOF

echo "[3/4] Configuring git delta (side-by-side, terminal color adaptive)..."
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.side-by-side true
git config --global delta.syntax-theme ansi

echo "[4/4] Updating ~/.bashrc CLI wrappers (eza, bat, man, duf)..."
if [[ -f "$HOME/.bashrc" && ! -f "$HOME/.bashrc.rice.bak" ]]; then
  cp -f "$HOME/.bashrc" "$HOME/.bashrc.rice.bak"
fi

touch "$HOME/.bashrc"
sed -i '/^# >>> rice-cli >>>$/,/^# <<< rice-cli <<<$/d' "$HOME/.bashrc"
cat <<'EOF' >> "$HOME/.bashrc"

# >>> rice-cli >>>
export EZA_COLORS="reset:di=1;34:ln=36:ex=32:da=2;37:ur=90:uw=90:ux=90:gr=90:gw=90:gx=90:tr=90:tw=90:tx=90"
alias ls='eza --group-directories-first'
alias ll='eza -la --group-directories-first --git'
alias la='eza -a --group-directories-first'
alias lt='eza --tree --level=2'
alias cat='bat --paging=never'
export MANROFFOPT="-c"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
df() {
  if [[ $# -eq 0 && -t 1 ]] && command -v duf >/dev/null 2>&1; then
    duf
  else
    command df "$@"
  fi
}
diff() {
  if [[ $# -eq 2 && -t 1 && -f "$1" && -f "$2" ]] && command -v delta >/dev/null 2>&1; then
    delta "$1" "$2"
  else
    command diff "$@"
  fi
}
# <<< rice-cli <<<
EOF

echo "Done. To activate: source ~/.bashrc"
echo "(Note: Use \\ls, \\cat, \\df, or \\diff to temporarily run the original commands.)"
