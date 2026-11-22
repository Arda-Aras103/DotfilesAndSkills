#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
THEME_SRC="$REPO_ROOT/configs/plymouth/ultrakill"
THEME_DST="/usr/share/plymouth/themes/ultrakill"
STATE_FILE="/etc/plymouth/.ultrakill-state"

RENDER_ONLY_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --render-only)
      [[ $# -ge 2 ]] || { echo "Missing directory for --render-only" >&2; exit 1; }
      RENDER_ONLY_DIR="$2"
      shift 2
      ;;
    --render-only=*)
      RENDER_ONLY_DIR="${1#*=}"
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [--render-only <dir>]

Install and activate the ULTRAKILL V1 Plymouth boot splash theme on Fedora,
or render all theme files into <dir> offline with --render-only.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

[[ -f "$THEME_SRC/ultrakill.plymouth" ]] || { echo "Missing manifest: $THEME_SRC/ultrakill.plymouth" >&2; exit 1; }
[[ -f "$THEME_SRC/ultrakill.script.tpl" ]] || { echo "Missing template: $THEME_SRC/ultrakill.script.tpl" >&2; exit 1; }

render_assets() {
  local out_dir="$1"
  mkdir -p "$out_dir"
  cp -f "$THEME_SRC/ultrakill.plymouth" "$out_dir/ultrakill.plymouth"

  python3 - "$THEME_SRC/ultrakill.script.tpl" "$out_dir" <<'PY'
import math
import os
import pathlib
import platform
import re
import shutil
import struct
import subprocess
import sys
import zlib

tpl_path = pathlib.Path(sys.argv[1])
out_dir = pathlib.Path(sys.argv[2])


def sanitize_text(raw: str, max_len: int) -> str:
    cleaned = re.sub(r"[\r\n\t]+", " ", raw)
    cleaned = "".join(ch for ch in cleaned if 32 <= ord(ch) <= 126 and ch not in ('"', "'", "\\"))
    cleaned = re.sub(r"\s+", " ", cleaned).strip().upper()
    if len(cleaned) > max_len:
        cleaned = cleaned[:max_len].rstrip()
    return cleaned


def detect_cpu() -> str:
    override = os.environ.get("ULTRAKILL_CPU", "")
    raw = override
    if not raw:
        try:
            for line in pathlib.Path("/proc/cpuinfo").read_text(encoding="utf-8", errors="ignore").splitlines():
                if line.lower().startswith("model name"):
                    raw = line.split(":", 1)[1].strip()
                    break
        except OSError:
            raw = ""
    raw = re.sub(r"\((?:R|TM|r|tm)\)", "", raw)
    raw = re.sub(r"\b(?:CPU|Processor)\b", "", raw, flags=re.IGNORECASE)
    raw = re.sub(r"\b(?:with|w/)\s+Radeon\s+Graphics\b", "", raw, flags=re.IGNORECASE)
    raw = re.sub(r"\s+@\s*.*$", "", raw)
    return sanitize_text(raw, 24) or "X86_64"


def detect_gpu() -> str:
    override = os.environ.get("ULTRAKILL_GPU", "")
    raw = override
    if not raw and shutil.which("lspci"):
        try:
            proc = subprocess.run(["lspci"], text=True, capture_output=True, check=False)
            candidates = []
            for line in proc.stdout.splitlines():
                low = line.lower()
                if "vga compatible controller" in low or "3d controller" in low or "display controller" in low:
                    desc = line.split(": ", 1)[1] if ": " in line else line
                    score = 2 if ("nvidia" in low or "amd" in low or "ati" in low) else 1
                    candidates.append((score, desc))
            if candidates:
                candidates.sort(key=lambda item: item[0], reverse=True)
                raw = candidates[0][1]
        except Exception:
            raw = ""
    raw = re.sub(r"\(rev\s+[^)]+\)", "", raw, flags=re.IGNORECASE)
    raw = re.sub(r"\[AMD/ATI\]", "", raw, flags=re.IGNORECASE)
    raw = re.sub(r"\[NVIDIA\]", "", raw, flags=re.IGNORECASE)
    bracket = re.search(r"\[([^\]]+)\]", raw)
    if bracket:
        raw = bracket.group(1)
    raw = re.sub(r"\b(?:NVIDIA|AMD|ATI|Intel)\s+Corporation\b", "", raw, flags=re.IGNORECASE)
    raw = re.sub(r"\bAdvanced Micro Devices,\s*Inc\.?\b", "", raw, flags=re.IGNORECASE)
    raw = re.sub(r"\b(?:GeForce|Radeon)\s+", "", raw, flags=re.IGNORECASE)
    raw = re.sub(r"\s*/\s*Mobile\b", "", raw, flags=re.IGNORECASE)
    return sanitize_text(raw, 24) or "DRM / KMS"


def detect_mem() -> str:
    override = os.environ.get("ULTRAKILL_MEM", "")
    if override.strip():
        val = override.strip()
        if val.isdigit():
            gb = max(1, round(int(val) / 1024))
            return f"{gb} GB"
        return sanitize_text(val, 20) or "SYSTEM RAM"
    try:
        for line in pathlib.Path("/proc/meminfo").read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("MemTotal:"):
                kb = int(line.split()[1])
                gb = max(1, round(kb / (1024 * 1024)))
                return f"{gb} GB"
    except Exception:
        pass
    return "SYSTEM RAM"


def detect_kernel() -> str:
    raw = os.environ.get("ULTRAKILL_KERNEL", "") or platform.release()
    raw = re.sub(r"\.(?:x86_64|aarch64)$", "", raw)
    return sanitize_text(raw, 22) or "LINUX"


def detect_hostname() -> str:
    raw = os.environ.get("ULTRAKILL_HOST", "") or platform.node()
    return sanitize_text(raw, 20) or "FEDORA"


def fmt_check(key: str, val: str, width: int = 52) -> str:
    prefix = f"{key:<9} [{val}] "
    dots_len = max(3, width - len(prefix) - 1)
    return prefix + ("." * dots_len) + " "


cpu_label = detect_cpu()
gpu_label = detect_gpu()
mem_label = detect_mem()
kernel_label = detect_kernel()
host_label = detect_hostname()

replacements = {
    "__KERNEL__": kernel_label,
    "__HOSTNAME__": host_label,
    "__KERNEL_LINE__": fmt_check("KERNEL", kernel_label),
    "__CPU_LINE__": fmt_check("CPU", cpu_label),
    "__GPU_LINE__": fmt_check("GPU", gpu_label),
    "__MEM_LINE__": fmt_check("MEMORY", mem_label),
    "__AUDIO_LINE__": fmt_check("AUDIO", "PIPEWIRE / ALSA"),
    "__VIDEO_LINE__": fmt_check("VIDEO", "DRM / WAYLAND"),
    "__MECH_LINE__": fmt_check("MECHANICS", "SYSTEMD / DBUS"),
}

rendered = tpl_path.read_text(encoding="utf-8")
for token, value in replacements.items():
    rendered = rendered.replace(token, value)

(out_dir / "ultrakill.script").write_text(rendered, encoding="utf-8")


def write_solid_png(path: pathlib.Path, r: int, g: int, b: int) -> None:
    row = b"\x00" + bytes((r, g, b)) * 2
    raw = row * 2

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", 2, 2, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
    path.write_bytes(png)


write_solid_png(out_dir / "bar-bg.png", 26, 10, 13)      # #1a0a0d
write_solid_png(out_dir / "bar-fill.png", 242, 31, 56)   # #f21f38
write_solid_png(out_dir / "bar-border.png", 89, 18, 28)  # #59121c
PY
}

if [[ -n "$RENDER_ONLY_DIR" ]]; then
  render_assets "$RENDER_ONLY_DIR"
  echo "Rendered ULTRAKILL Plymouth theme assets into $RENDER_ONLY_DIR"
  exit 0
fi

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
  if [[ "$PREV_THEME" == "ultrakill" || "$PREV_THEME" == "cyber-tokyo" ]]; then
    PREV_THEME="bgrt"
  fi
fi

echo "[2/4] Rendering and installing ultrakill Plymouth theme into $THEME_DST..."
TMP_ASSETS="$(mktemp -d)"
trap 'rm -rf "$TMP_ASSETS"' EXIT
render_assets "$TMP_ASSETS"

sudo install -d -m 755 "$THEME_DST" /etc/plymouth
for f in ultrakill.plymouth ultrakill.script bar-bg.png bar-fill.png bar-border.png; do
  sudo install -m 644 "$TMP_ASSETS/$f" "$THEME_DST/$f"
done

printf 'PREV_THEME=%s\nINSTALLED_PLUGIN=%s\n' "$PREV_THEME" "$INSTALLED_PLUGIN" | sudo tee "$STATE_FILE" >/dev/null
sudo chmod 644 "$STATE_FILE"

echo "[3/4] Setting Plymouth theme and rebuilding initramfs (takes ~15-30s)..."
sudo plymouth-set-default-theme ultrakill -R

echo "[4/4] Done! ULTRAKILL V1 boot splash is active."
echo "Revert cleanly at any time with:"
echo "  bash $SCRIPT_DIR/plymouth-ultrakill-revert.sh"
