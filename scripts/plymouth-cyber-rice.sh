#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
THEME_SRC="$REPO_ROOT/configs/plymouth/cyber-tokyo"
THEME_DST="/usr/share/plymouth/themes/cyber-tokyo"
STATE_FILE="/etc/plymouth/.cyber-tokyo-state"

echo "[1/4] Checking Plymouth script plugin..."
INSTALLED_PLUGIN=0
if ! rpm -q plymouth-plugin-script >/dev/null 2>&1; then
  sudo dnf install -y plymouth-plugin-script
  INSTALLED_PLUGIN=1
fi

PREV_THEME=""
if sudo test -f "$STATE_FILE"; then
  PREV_THEME="$(sudo awk -F= '/^PREV_THEME=/{print $2; exit}' "$STATE_FILE" 2>/dev/null || true)"
  OLD_INST="$(sudo awk -F= '/^INSTALLED_PLUGIN=/{print $2; exit}' "$STATE_FILE" 2>/dev/null || true)"
  [[ "${OLD_INST:-0}" == "1" ]] && INSTALLED_PLUGIN=1
fi
if [[ -z "$PREV_THEME" ]]; then
  PREV_THEME="$(plymouth-set-default-theme 2>/dev/null || echo bgrt)"
  [[ "$PREV_THEME" == "cyber-tokyo" ]] && PREV_THEME="bgrt"
fi

echo "[2/4] Installing cyber-tokyo Plymouth theme into $THEME_DST..."
sudo install -d -m 755 "$THEME_DST" /etc/plymouth
sudo install -m 644 "$THEME_SRC/cyber-tokyo.plymouth" "$THEME_DST/cyber-tokyo.plymouth"
sudo install -m 644 "$THEME_SRC/cyber-tokyo.script" "$THEME_DST/cyber-tokyo.script"

TMP_ASSETS="$(mktemp -d)"
trap 'rm -rf "$TMP_ASSETS"' EXIT
python3 - "$TMP_ASSETS" <<'PY'
import pathlib
import struct
import sys
import zlib

out = pathlib.Path(sys.argv[1])

def write_solid_png(path: pathlib.Path, r: int, g: int, b: int) -> None:
    row = b"\x00" + bytes((r, g, b)) * 2
    raw = row * 2
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", 2, 2, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
    path.write_bytes(png)

write_solid_png(out / "bar-bg.png", 34, 26, 20)       # #221a14
write_solid_png(out / "bar-fill.png", 193, 156, 123)  # #c19c7b
write_solid_png(out / "bar-border.png", 122, 162, 247) # #7aa2f7
PY
for img in bar-bg.png bar-fill.png bar-border.png; do
  sudo install -m 644 "$TMP_ASSETS/$img" "$THEME_DST/$img"
done

printf 'PREV_THEME=%s\nINSTALLED_PLUGIN=%s\n' "$PREV_THEME" "$INSTALLED_PLUGIN" | sudo tee "$STATE_FILE" >/dev/null
sudo chmod 644 "$STATE_FILE"

echo "[3/4] Setting Plymouth theme and rebuilding initramfs (takes ~15-30s)..."
sudo plymouth-set-default-theme cyber-tokyo -R

echo "[4/4] Done! cyber-tokyo boot splash is active."
echo "Revert cleanly at any time with:"
echo "  bash $SCRIPT_DIR/plymouth-cyber-revert.sh"
