#!/usr/bin/env bash
set -euo pipefail

YAZI_DIR="$HOME/.config/yazi"

echo "[1/4] Installing yazi via COPR..."
sudo dnf install -y dnf-plugins-core
sudo dnf copr enable -y lihaohong/yazi
sudo dnf install -y yazi

echo "[2/4] Writing yazi base settings, Tokyo Night theme, and plugins..."
mkdir -p "$YAZI_DIR"
for f in yazi.toml theme.toml package.toml init.lua keymap.toml; do
  if [[ -f "$YAZI_DIR/$f" && ! -f "$YAZI_DIR/$f.rice.bak" ]]; then
    cp -f "$YAZI_DIR/$f" "$YAZI_DIR/$f.rice.bak"
  fi
done

cat <<'EOF' > "$YAZI_DIR/yazi.toml"
[mgr]
ratio = [1, 3, 4]
sort_by = "natural"
sort_dir_first = true
show_hidden = false

[plugin]
prepend_fetchers = [
  { url = "*",  run = "git", group = "git" },
  { url = "*/", run = "git", group = "git" },
]
EOF

if command -v ya >/dev/null 2>&1; then
  ya pkg add BennyOe/tokyo-night >/dev/null 2>&1 || true
  ya pkg add yazi-rs/plugins:git yazi-rs/plugins:full-border yazi-rs/plugins:smart-enter >/dev/null 2>&1 || true
fi

cat <<'EOF' > "$YAZI_DIR/init.lua"
local ok_fb, full_border = pcall(require, "full-border")
if ok_fb then full_border:setup() end
local ok_git, git = pcall(require, "git")
if ok_git then git:setup({ order = 1500 }) end
EOF

cat <<'EOF' > "$YAZI_DIR/keymap.toml"
[[mgr.prepend_keymap]]
on   = "<Enter>"
run  = "plugin smart-enter"
desc = "Enter the child directory, or open the file"
EOF

if [[ -d "$YAZI_DIR/flavors/tokyo-night.yazi" ]]; then
  cat <<'EOF' > "$YAZI_DIR/theme.toml"
[flavor]
dark = "tokyo-night"
EOF
fi

echo "[3/4] Adding 'y' directory-changing wrapper to ~/.bashrc..."
if [[ -f "$HOME/.bashrc" && ! -f "$HOME/.bashrc.yazi.bak" ]]; then
  cp -f "$HOME/.bashrc" "$HOME/.bashrc.yazi.bak"
fi

touch "$HOME/.bashrc"
sed -i '/^# >>> rice-yazi >>>$/,/^# <<< rice-yazi <<<$/d' "$HOME/.bashrc"
cat <<'EOF' >> "$HOME/.bashrc"

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
EOF

echo "[4/4] Done. To activate: exec bash (then run 'y' to launch)"
