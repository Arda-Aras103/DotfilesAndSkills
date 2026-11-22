#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_step() {
  local script="$1"
  if [[ -f "$script" ]]; then
    bash "$script" || echo "[Warn] $(basename "$script") partially failed, continuing..."
  fi
}

echo "=== [1/5] Reverting Projects (KQuickLook, KZapret, Zen Extensions) ==="
run_step "$DIR/projects-revert.sh"

echo "=== [2/5] Reverting Terminal, CLI & TUI Tools ==="
run_step "$DIR/yazi-revert.sh"
run_step "$DIR/dev-input-revert.sh"
run_step "$DIR/tui-revert.sh"
run_step "$DIR/cli-revert.sh"
run_step "$DIR/fastfetch-revert.sh"
run_step "$DIR/terminal-revert.sh"

echo "=== [3/5] Reverting GTK, Zen Browser, Zed & Obsidian ==="
run_step "$DIR/obsidian-revert.sh"
run_step "$DIR/zed-revert.sh"
run_step "$DIR/zen-revert.sh"
run_step "$DIR/gtk-revert.sh"

echo "=== [4/5] Reverting Panel, Cursor & Lock/SDDM ==="
run_step "$DIR/lock-sddm-revert.sh"
run_step "$DIR/icons-cursor-revert.sh"
run_step "$DIR/panel-dropdown-revert.sh"
run_step "$DIR/music-revert.sh"
run_step "$DIR/desktop-revert.sh"
run_step "$DIR/panel-revert.sh"
rm -rf "$HOME/.config/panel-colorizer/presets/TokyoNight"

echo "=== [5/5] Reverting KDE Desktop, KWin, Shortcuts & Settings ==="
run_step "$DIR/krunner-revert.sh"
run_step "$DIR/extras-revert.sh"
run_step "$DIR/workflow-polish-revert.sh"
run_step "$DIR/settings-clean-revert.sh"
run_step "$DIR/ergonomics-revert.sh"
run_step "$DIR/windows-revert.sh"
command -v plasma-apply-colorscheme >/dev/null 2>&1 && plasma-apply-colorscheme BreezeDark >/dev/null 2>&1 || true
run_step "$DIR/kde-hyprland-revert.sh"

echo ""
echo "All rice changes and installed extra packages reverted. To reload your shell: exec bash"
