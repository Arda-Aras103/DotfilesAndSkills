#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== [1/5] KDE Desktop, KWin, Shortcuts & Settings ==="
"$DIR/kde-hyprland-rice.sh"
"$DIR/theme-toggle.sh" tokyo
"$DIR/windows-rice.sh"
"$DIR/ergonomics-rice.sh"
"$DIR/settings-clean-rice.sh"
"$DIR/workflow-polish-rice.sh"
"$DIR/extras-rice.sh"
"$DIR/krunner-rice.sh"

echo "=== [2/5] Top Panel Island Mode, Cursor & Lock/SDDM ==="
"$DIR/panel-rice.sh"
"$DIR/panel-colorizer-tokyo.sh"
"$DIR/desktop-clean.sh"
"$DIR/music-rice.sh"
"$DIR/panel-dropdown-rice.sh"
"$DIR/icons-cursor-rice.sh"
"$DIR/lock-sddm-rice.sh"

echo "=== [3/5] GTK, Zen Browser, Zed & Obsidian ==="
"$DIR/gtk-rice.sh"
"$DIR/zen-rice.sh" || echo "[Warn] Zen profile not found; launch Zen once and run zen-rice.sh."
"$DIR/zed-rice.sh"
"$DIR/obsidian-rice.sh" "$DIR/../notes" || echo "[Warn] Obsidian vault not ready; run obsidian-rice.sh later."

echo "=== [4/5] Terminal, CLI & TUI Tools ==="
"$DIR/terminal-rice.sh"
"$DIR/fastfetch-rice.sh"
"$DIR/cli-rice.sh"
"$DIR/tui-rice.sh"
"$DIR/dev-input-rice.sh"
"$DIR/yazi-rice.sh"

echo "=== [5/5] Projects (KQuickLook, KZapret, Zen Extensions) ==="
bash "$DIR/projects-rice.sh"

echo ""
echo "All setup complete. Run to reload your shell: exec bash"
echo "(Note: environment.d and SDDM take full effect on next login; restart Zen Browser.)"
