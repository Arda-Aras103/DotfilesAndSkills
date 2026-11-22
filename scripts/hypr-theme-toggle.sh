#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
THEMES_SRC="$REPO_ROOT/configs/hypr/themes"
OVERLAYS_SRC="$REPO_ROOT/configs/hypr/overlays"

REAL_HOME="$HOME"
THEME_HOME="${HYPR_THEME_HOME:-$HOME}"
IS_SANDBOX=0
if [[ "$THEME_HOME" != "$REAL_HOME" ]]; then
  IS_SANDBOX=1
fi

HYPR_DIR="${HYPR_CONFIG_HOME:-$THEME_HOME/.config/hypr}"
QS_DIR="$THEME_HOME/.config/quickshell"
STATE_DIR="$THEME_HOME/.local/state/hypr-themes"
STATE_FILE="$STATE_DIR/state.json"
HYPR_LUA="$HYPR_DIR/hyprland.lua"

THEMES=(persona balatro minflair carpet minecraft desk)

DRY_RUN=0
WALLPAPER_ARG=""
HAS_WALLPAPER=0
ACTIVATE_CMD=""
ACTION=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [persona|balatro|minflair|carpet|minecraft|desk|cycle|list|status] [OPTIONS]

Options:
  --wallpaper <path>              Wallpaper image path (used by minflair palette extraction)
  --activate-linux [on|off|toggle] Control Activate Linux watermark overlay
  --dry-run                       Print planned changes without writing files or spawning processes
  -h, --help                      Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    persona|balatro|minflair|carpet|minecraft|desk|cycle|toggle|list|status)
      [[ -z "$ACTION" ]] || { echo "Multiple actions specified: $ACTION and $1" >&2; exit 1; }
      ACTION="$1"
      shift
      ;;
    --wallpaper)
      [[ $# -ge 2 ]] || { echo "Missing value for --wallpaper" >&2; exit 1; }
      WALLPAPER_ARG="$2"
      HAS_WALLPAPER=1
      shift 2
      ;;
    --wallpaper=*)
      WALLPAPER_ARG="${1#*=}"
      HAS_WALLPAPER=1
      shift
      ;;
    --activate-linux)
      if [[ $# -ge 2 ]] && [[ "$2" == "on" || "$2" == "off" || "$2" == "toggle" ]]; then
        ACTIVATE_CMD="$2"
        shift 2
      else
        ACTIVATE_CMD="toggle"
        shift
      fi
      ;;
    --activate-linux=*)
      ACTIVATE_CMD="${1#*=}"
      case "$ACTIVATE_CMD" in
        on|off|toggle) ;;
        *) echo "Invalid --activate-linux value: $ACTIVATE_CMD" >&2; exit 1 ;;
      esac
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ACTION" ]]; then
  if [[ -n "$ACTIVATE_CMD" ]]; then
    ACTION="overlay-only"
  else
    ACTION="cycle"
  fi
fi

if [[ "$ACTION" == "list" ]]; then
  printf '%s\n' "${THEMES[@]}"
  exit 0
fi

read_state_json() {
  python3 - "$STATE_FILE" "$1" "${2:-}" <<'PY'
import json
import sys

path, key, default = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.loads(open(path, encoding="utf-8").read())
    val = data.get(key, default)
except Exception:
    val = default
if isinstance(val, bool):
    print("on" if val else "off")
elif val is None:
    print(default)
else:
    print(val)
PY
}

CURRENT_THEME="$(read_state_json active_theme persona)"
CURRENT_ACTIVATE="$(read_state_json activate_linux off)"
CURRENT_WALLPAPER="$(read_state_json wallpaper "")"

if [[ "$ACTION" == "status" ]]; then
  echo "active_theme=$CURRENT_THEME"
  echo "activate_linux=$CURRENT_ACTIVATE"
  echo "wallpaper=$CURRENT_WALLPAPER"
  echo "hypr_dir=$HYPR_DIR"
  echo "quickshell_dir=$QS_DIR"
  exit 0
fi

if [[ "$HAS_WALLPAPER" -eq 1 && -n "$WALLPAPER_ARG" ]]; then
  RESOLVED_WALLPAPER="$(python3 -c 'import os,sys; print(os.path.abspath(os.path.expanduser(sys.argv[1])))' "$WALLPAPER_ARG")"
  [[ -f "$RESOLVED_WALLPAPER" ]] || { echo "Wallpaper not found: $RESOLVED_WALLPAPER" >&2; exit 1; }
else
  RESOLVED_WALLPAPER="$CURRENT_WALLPAPER"
fi

TARGET_THEME="$CURRENT_THEME"
case "$ACTION" in
  persona|balatro|minflair|carpet|minecraft|desk)
    TARGET_THEME="$ACTION"
    ;;
  cycle|toggle)
    TARGET_THEME="${THEMES[0]}"
    for i in "${!THEMES[@]}"; do
      if [[ "${THEMES[$i]}" == "$CURRENT_THEME" ]]; then
        NEXT_IDX=$(( (i + 1) % ${#THEMES[@]} ))
        TARGET_THEME="${THEMES[$NEXT_IDX]}"
        break
      fi
    done
    ;;
  overlay-only)
    TARGET_THEME="$CURRENT_THEME"
    ;;
esac

TARGET_ACTIVATE="$CURRENT_ACTIVATE"
if [[ -n "$ACTIVATE_CMD" ]]; then
  case "$ACTIVATE_CMD" in
    on) TARGET_ACTIVATE="on" ;;
    off) TARGET_ACTIVATE="off" ;;
    toggle)
      if [[ "$CURRENT_ACTIVATE" == "on" ]]; then
        TARGET_ACTIVATE="off"
      else
        TARGET_ACTIVATE="on"
      fi
      ;;
  esac
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] target_theme=$TARGET_THEME"
  echo "[dry-run] activate_linux=$TARGET_ACTIVATE"
  echo "[dry-run] wallpaper=$RESOLVED_WALLPAPER"
  echo "[dry-run] hypr_lua=$HYPR_LUA"
  echo "[dry-run] quickshell_dir=$QS_DIR/$TARGET_THEME"
  exit 0
fi

mkdir -p "$HYPR_DIR" "$QS_DIR/overlays" "$STATE_DIR"

# Back up pre-existing user hyprland.lua only once before this switcher manages it
if [[ -f "$HYPR_LUA" && ! -f "$HYPR_LUA.rice.bak" && ! -f "$STATE_DIR/managed-hypr-lua" ]]; then
  cp -f "$HYPR_LUA" "$HYPR_LUA.rice.bak"
fi
touch "$STATE_DIR/managed-hypr-lua"

# Always stage ActivateLinux and CyberLock overlays
cp -f "$OVERLAYS_SRC/ActivateLinux.qml" "$QS_DIR/overlays/ActivateLinux.qml"
cp -f "$OVERLAYS_SRC/CyberLock.qml" "$QS_DIR/overlays/CyberLock.qml"
if [[ -f "$REPO_ROOT/configs/sddm/cyber-wireframe/login-photo.jpg" ]]; then
  cp -f "$REPO_ROOT/configs/sddm/cyber-wireframe/login-photo.jpg" "$QS_DIR/overlays/login-photo.jpg"
fi

# Detect keyboard layout from kxkbrc (read-only!)
KB_LAYOUT="$(python3 - "$THEME_HOME/.config/kxkbrc" "$REAL_HOME/.config/kxkbrc" <<'PY'
import configparser
import os
import sys

for candidate in sys.argv[1:]:
    if candidate and os.path.exists(candidate):
        cfg = configparser.ConfigParser(interpolation=None, strict=False)
        cfg.optionxform = str
        cfg.read(candidate, encoding="utf-8")
        raw = cfg.get("Layout", "LayoutList", fallback="")
        layouts = ",".join(part.strip() for part in raw.split(",") if part.strip())
        if layouts:
            print(layouts)
            raise SystemExit(0)
print("us")
PY
)"

# Stage profile assets & derive Hyprland aesthetic tokens
ACTIVE_BORDER="rgb(7aa2f7)"
INACTIVE_BORDER="rgb(414868)"
GAPS_IN=4
GAPS_OUT=8
BORDER_SIZE=2
ROUNDING=6

case "$TARGET_THEME" in
  persona)
    if [[ ! -f "$QS_DIR/persona/shell.qml" ]]; then
      echo "[warn] $QS_DIR/persona/shell.qml not found; run persona-hyprland-setup.sh to install Persona-Quickshell." >&2
    fi
    ACTIVE_BORDER="rgb(e6202a)"
    INACTIVE_BORDER="rgb(2a2f42)"
    GAPS_IN=4
    GAPS_OUT=8
    BORDER_SIZE=2
    ROUNDING=6
    ;;

  balatro)
    mkdir -p "$QS_DIR/balatro"
    cp -f "$THEMES_SRC/balatro/shell.qml" "$QS_DIR/balatro/shell.qml"
    cp -f "$THEMES_SRC/balatro/balatro.frag" "$QS_DIR/balatro/balatro.frag"
    HAS_QSB="false"
    QSB_BIN=""
    for cand in qsb qsb-qt6 /usr/lib64/qt6/bin/qsb; do
      if command -v "$cand" >/dev/null 2>&1; then
        QSB_BIN="$cand"
        break
      fi
    done
    if [[ -n "$QSB_BIN" ]]; then
      if "$QSB_BIN" --glsl "100 es,120,150" --hlsl 50 --msl 12 \
          -o "$QS_DIR/balatro/balatro.frag.qsb" \
          "$QS_DIR/balatro/balatro.frag" >/dev/null 2>&1; then
        HAS_QSB="true"
      fi
    fi
    cat > "$QS_DIR/balatro/ThemeConfig.qml" <<EOF
import QtQuick

QtObject {
    readonly property bool hasQsbShader: $HAS_QSB
    readonly property url qsbUrl: Qt.resolvedUrl("balatro.frag.qsb")
}
EOF
    ACTIVE_BORDER="rgb(de443b)"
    INACTIVE_BORDER="rgb(006bb4)"
    GAPS_IN=5
    GAPS_OUT=10
    BORDER_SIZE=3
    ROUNDING=8
    ;;

  minflair)
    mkdir -p "$QS_DIR/minflair"
    cp -f "$THEMES_SRC/minflair/shell.qml" "$QS_DIR/minflair/shell.qml"
    PALETTE_JSON="$(python3 - "$RESOLVED_WALLPAPER" <<'PY'
import colorsys
import hashlib
import json
import math
import pathlib
import struct
import sys
import zlib

wall = sys.argv[1] if len(sys.argv) > 1 else ""

def clamp8(v: float) -> int:
    return max(0, min(255, int(round(v))))

def to_hex(rgb: tuple[int, int, int]) -> str:
    return f"#{clamp8(rgb[0]):02x}{clamp8(rgb[1]):02x}{clamp8(rgb[2]):02x}"

def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c

def sample_ppm(data: bytes) -> list[tuple[int, int, int]]:
    if data.startswith(b"P6"):
        idx = 2
        tokens: list[bytes] = []
        n = len(data)
        while len(tokens) < 3 and idx < n:
            while idx < n and data[idx] in b" \t\r\n":
                idx += 1
            if idx < n and data[idx] == ord("#"):
                while idx < n and data[idx] != ord("\n"):
                    idx += 1
                continue
            start = idx
            while idx < n and data[idx] not in b" \t\r\n#":
                idx += 1
            if idx > start:
                tokens.append(data[start:idx])
        if len(tokens) == 3:
            w, h, maxv = int(tokens[0]), int(tokens[1]), max(1, int(tokens[2]))
            if idx < n and data[idx] in b" \t\r\n":
                idx += 1
            raw = data[idx:]
            pixels: list[tuple[int, int, int]] = []
            total = w * h
            step = max(1, total // 8000)
            for p in range(0, min(total, len(raw) // 3), step):
                off = p * 3
                r = raw[off] * 255 // maxv
                g = raw[off + 1] * 255 // maxv
                b = raw[off + 2] * 255 // maxv
                pixels.append((r, g, b))
            return pixels
    elif data.startswith(b"P3"):
        lines = []
        for line in data.decode("ascii", errors="ignore").splitlines():
            line = line.split("#", 1)[0].strip()
            if line:
                lines.extend(line.split())
        if len(lines) >= 4:
            w, h, maxv = int(lines[1]), int(lines[2]), max(1, int(lines[3]))
            vals = [int(x) * 255 // maxv for x in lines[4:]]
            total = min(w * h, len(vals) // 3)
            step = max(1, total // 8000)
            return [(vals[i * 3], vals[i * 3 + 1], vals[i * 3 + 2]) for i in range(0, total, step)]
    return []

def sample_png(data: bytes) -> list[tuple[int, int, int]]:
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return []
    pos = 8
    width = height = bit_depth = color_type = interlace = 0
    plte = b""
    idat = bytearray()
    while pos + 8 <= len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR" and len(chunk) >= 13:
            width, height, bit_depth, color_type, _comp, _filt, interlace = struct.unpack(">IIBBBBB", chunk[:13])
        elif ctype == b"PLTE":
            plte = chunk
        elif ctype == b"IDAT":
            idat.extend(chunk)
        elif ctype == b"IEND":
            break

    if width <= 0 or height <= 0 or interlace != 0 or bit_depth not in (8, 16):
        return []
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type)
    if channels is None:
        return []

    raw = zlib.decompress(bytes(idat))
    byte_width = bit_depth // 8
    bpp = channels * byte_width
    stride = width * bpp
    expected = (stride + 1) * height
    if len(raw) < expected:
        return []

    pixels: list[tuple[int, int, int]] = []
    y_step = max(1, height // 120)
    x_step = max(1, width // 120)
    prev = bytearray(stride)

    for y in range(height):
        row_start = y * (stride + 1)
        ftype = raw[row_start]
        src = raw[row_start + 1:row_start + 1 + stride]
        cur = bytearray(stride)
        if ftype == 0:
            cur[:] = src
        elif ftype == 1:
            for i in range(stride):
                left = cur[i - bpp] if i >= bpp else 0
                cur[i] = (src[i] + left) & 0xFF
        elif ftype == 2:
            for i in range(stride):
                cur[i] = (src[i] + prev[i]) & 0xFF
        elif ftype == 3:
            for i in range(stride):
                left = cur[i - bpp] if i >= bpp else 0
                cur[i] = (src[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:
            for i in range(stride):
                left = cur[i - bpp] if i >= bpp else 0
                up = prev[i]
                up_left = prev[i - bpp] if i >= bpp else 0
                cur[i] = (src[i] + paeth(left, up, up_left)) & 0xFF
        else:
            return []

        if y % y_step == 0:
            for x in range(0, width, x_step):
                off = x * bpp
                if color_type == 2:
                    r, g, b = cur[off], cur[off + byte_width], cur[off + 2 * byte_width]
                elif color_type == 6:
                    r, g, b = cur[off], cur[off + byte_width], cur[off + 2 * byte_width]
                elif color_type == 0:
                    v = cur[off]
                    r = g = b = v
                elif color_type == 4:
                    v = cur[off]
                    r = g = b = v
                elif color_type == 3:
                    idx = cur[off] * 3
                    if idx + 2 < len(plte):
                        r, g, b = plte[idx], plte[idx + 1], plte[idx + 2]
                    else:
                        continue
                pixels.append((r, g, b))
        prev = cur
    return pixels

def sample_jpeg_dc(data: bytes) -> list[tuple[int, int, int]]:
    if not data.startswith(b"\xff\xd8"):
        return []
    i, n = 2, len(data)
    dqt: dict[int, int] = {}
    dht: dict[tuple[int, int], dict[tuple[int, int], int]] = {}
    sof = None
    dri = 0
    scan_comps = []
    al = 0
    entropy_pos = -1
    while i < n:
        if data[i] != 0xFF:
            i += 1
            continue
        while i < n and data[i] == 0xFF:
            i += 1
        if i >= n:
            break
        m = data[i]
        i += 1
        if m in (0xD8, 0xD9) or (0xD0 <= m <= 0xD7):
            continue
        if i + 2 > n:
            break
        seg_len = int.from_bytes(data[i:i + 2], "big")
        if seg_len < 2 or i + seg_len > n:
            break
        seg = data[i + 2:i + seg_len]
        if m == 0xDB:
            p = 0
            while p < len(seg):
                tq, prec = seg[p] & 0x0F, seg[p] >> 4
                p += 1
                dqt[tq] = seg[p] if prec == 0 else int.from_bytes(seg[p:p + 2], "big")
                p += 64 * (2 if prec else 1)
        elif m == 0xDD and len(seg) >= 2:
            dri = int.from_bytes(seg[:2], "big")
        elif m in (0xC0, 0xC2) and len(seg) >= 6:
            h_px = int.from_bytes(seg[1:3], "big")
            w_px = int.from_bytes(seg[3:5], "big")
            comps = [(seg[6 + 3 * c], seg[7 + 3 * c] >> 4, seg[7 + 3 * c] & 0x0F, seg[8 + 3 * c]) for c in range(seg[5])]
            sof = (m, w_px, h_px, comps)
        elif m == 0xC4:
            p = 0
            while p < len(seg):
                tc_th = seg[p]
                p += 1
                counts = seg[p:p + 16]
                p += 16
                tbl: dict[tuple[int, int], int] = {}
                code = 0
                for bits, cnt in enumerate(counts, 1):
                    for _ in range(cnt):
                        tbl[(bits, code)] = seg[p]
                        p += 1
                        code += 1
                    code <<= 1
                dht[(tc_th >> 4, tc_th & 0x0F)] = tbl
        elif m == 0xDA and len(seg) >= 4:
            ns = seg[0]
            scan_comps = [(seg[1 + 2 * c], seg[2 + 2 * c] >> 4, seg[2 + 2 * c] & 0x0F) for c in range(ns)]
            al = seg[3 + 2 * ns] & 0x0F
            entropy_pos = i + seg_len
            break
        i += seg_len
    if sof is None or entropy_pos < 0 or not scan_comps or not all((0, td) in dht for _, td, _ in scan_comps):
        return []
    sof_marker, w_px, h_px, comps = sof
    raw = bytearray()
    rst_positions: list[int] = []
    p = entropy_pos
    while p < n - 1:
        b = data[p]
        if b == 0xFF:
            nxt = data[p + 1]
            if nxt == 0x00:
                raw.append(0xFF)
                p += 2
                continue
            elif 0xD0 <= nxt <= 0xD7:
                rst_positions.append(len(raw) * 8)
                p += 2
                continue
            break
        raw.append(b)
        p += 1
    nbits, bit_idx = len(raw) * 8, 0
    def get_bit() -> int:
        nonlocal bit_idx
        if bit_idx >= nbits:
            return 0
        b_val = (raw[bit_idx >> 3] >> (7 - (bit_idx & 7))) & 1
        bit_idx += 1
        return b_val
    def get_bits(cnt: int) -> int:
        val = 0
        for _ in range(cnt):
            val = (val << 1) | get_bit()
        return val
    def decode_huff(tbl: dict[tuple[int, int], int]) -> int:
        code = 0
        for length in range(1, 17):
            code = (code << 1) | get_bit()
            if (length, code) in tbl:
                return tbl[(length, code)]
        return 0
    def extend(val: int, t: int) -> int:
        if t == 0:
            return 0
        return val - (1 << t) + 1 if val < (1 << (t - 1)) else val
    comp_map = {cid: (hv_h, hv_v, tq) for cid, hv_h, hv_v, tq in comps}
    max_h = max(c[1] for c in comps)
    max_v = max(c[2] for c in comps)
    mcus_x = max(1, (w_px + max_h * 8 - 1) // (max_h * 8))
    mcus_y = max(1, (h_px + max_v * 8 - 1) // (max_v * 8))
    preds = {cid: 0 for cid, _, _, _ in comps}
    pixels: list[tuple[int, int, int]] = []
    rst_idx = 0
    for mcu_i in range(mcus_x * mcus_y):
        if dri and mcu_i > 0 and mcu_i % dri == 0:
            if rst_idx < len(rst_positions):
                bit_idx = rst_positions[rst_idx]
                rst_idx += 1
            elif bit_idx & 7:
                bit_idx = (bit_idx + 7) & ~7
            preds = {cid: 0 for cid, _, _, _ in comps}
        if bit_idx >= nbits:
            break
        comp_vals: dict[int, float] = {}
        for cid, td, ta in scan_comps:
            hv_h, hv_v, tq = comp_map[cid]
            q0 = dqt.get(tq, 16)
            dc_sum = 0.0
            blocks = max(1, hv_h * hv_v)
            for _ in range(blocks):
                t = decode_huff(dht[(0, td)])
                preds[cid] += extend(get_bits(t), t)
                dc_sum += (preds[cid] << al) * q0
                if sof_marker == 0xC0 and (1, ta) in dht:
                    k = 1
                    while k < 64:
                        rs = decode_huff(dht[(1, ta)])
                        r_run, s_sz = rs >> 4, rs & 0x0F
                        if s_sz == 0:
                            if r_run == 15:
                                k += 16
                                continue
                            break
                        get_bits(s_sz)
                        k += r_run + 1
            comp_vals[cid] = dc_sum / blocks
        if len(comps) == 1:
            y_val = clamp8(comp_vals.get(comps[0][0], 0.0) / 8.0 + 128.0)
            pixels.append((y_val, y_val, y_val))
        else:
            y_val = comp_vals.get(comps[0][0], 0.0) / 8.0 + 128.0
            cb_val = comp_vals.get(comps[1][0], 0.0) / 8.0
            cr_val = comp_vals.get(comps[2][0], 0.0) / 8.0
            pixels.append((
                clamp8(y_val + 1.402 * cr_val),
                clamp8(y_val - 0.344136 * cb_val - 0.714136 * cr_val),
                clamp8(y_val + 1.772 * cb_val),
            ))
    return pixels

def sample_pixels(path: str) -> list[tuple[int, int, int]]:
    if not path:
        return []
    p = pathlib.Path(path)
    if not p.is_file():
        return []
    data = p.read_bytes()
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        px = sample_png(data)
        if px:
            return px
    if data.startswith((b"P6", b"P3")):
        px = sample_ppm(data)
        if px:
            return px
    if data.startswith(b"\xff\xd8"):
        px = sample_jpeg_dc(data)
        if px:
            return px
    try:
        from PIL import Image  # optional enhancement for WebP/TIFF/etc. if installed
        with Image.open(p) as im:
            im = im.convert("RGB")
            im.thumbnail((128, 128))
            return list(im.getdata())
    except Exception:
        return []

def build_palette(path: str) -> dict[str, str]:
    pixels = sample_pixels(path)
    if not pixels:
        if path and pathlib.Path(path).is_file():
            digest = hashlib.sha256(pathlib.Path(path).read_bytes()[:65536]).digest()
            h1 = digest[0] / 255.0
            h2 = (h1 + 0.35) % 1.0
            bg_rgb = tuple(clamp8(c * 255) for c in colorsys.hls_to_rgb(h1, 0.09, 0.32))
            surf_rgb = tuple(clamp8(c * 255) for c in colorsys.hls_to_rgb(h1, 0.15, 0.28))
            p_rgb = tuple(clamp8(c * 255) for c in colorsys.hls_to_rgb(h1, 0.62, 0.72))
            s_rgb = tuple(clamp8(c * 255) for c in colorsys.hls_to_rgb(h2, 0.60, 0.68))
            fg_rgb = (232, 237, 245)
        else:
            bg_rgb = (16, 21, 28)
            surf_rgb = (27, 36, 48)
            fg_rgb = (230, 237, 243)
            p_rgb = (94, 234, 212)
            s_rgb = (245, 158, 11)
    else:
        buckets: dict[tuple[int, int, int], list[int]] = {}
        for r, g, b in pixels:
            key = (r // 24, g // 24, b // 24)
            acc = buckets.get(key)
            if acc is None:
                buckets[key] = [r, g, b, 1]
            else:
                acc[0] += r
                acc[1] += g
                acc[2] += b
                acc[3] += 1

        clusters = []
        for sr, sg, sb, cnt in buckets.values():
            mr, mg, mb = sr / cnt, sg / cnt, sb / cnt
            h, l, s = colorsys.rgb_to_hls(mr / 255.0, mg / 255.0, mb / 255.0)
            clusters.append((cnt, (mr, mg, mb), h, l, s))

        # Deepest dark background from image or darkened dominant tone
        dark_clusters = sorted(clusters, key=lambda c: c[3] - 0.05 * math.log1p(c[0]))
        dr, dg, db = dark_clusters[0][1]
        dh, dl, ds = colorsys.rgb_to_hls(dr / 255.0, dg / 255.0, db / 255.0)
        bg_l = min(0.13, max(0.06, dl * 0.6))
        bg_rgb = tuple(clamp8(c * 255) for c in colorsys.hls_to_rgb(dh, bg_l, min(0.45, ds)))
        surf_rgb = tuple(clamp8(c * 255) for c in colorsys.hls_to_rgb(dh, min(0.22, bg_l + 0.07), min(0.40, ds)))

        # Primary vivid accent
        vivid = sorted(
            clusters,
            key=lambda c: (c[4] * (0.45 + 0.55 * math.log1p(c[0]))) * (1.0 if 0.12 <= c[3] <= 0.88 else 0.4),
            reverse=True,
        )
        pr, pg, pb = vivid[0][1]
        ph, pl, ps = colorsys.rgb_to_hls(pr / 255.0, pg / 255.0, pb / 255.0)
        p_rgb = tuple(clamp8(c * 255) for c in colorsys.hls_to_rgb(ph, max(0.48, min(0.72, pl)), max(0.50, ps)))

        # Secondary distinct accent
        best_sec = vivid[0]
        best_score = -1.0
        for cand in vivid[1:]:
            dist = math.sqrt(sum((a - b) ** 2 for a, b in zip(cand[1], vivid[0][1]))) / 441.67
            score = dist * (0.4 + cand[4]) * (0.5 + 0.25 * math.log1p(cand[0]))
            if score > best_score:
                best_score = score
                best_sec = cand
        if best_score <= 0.05:
            s_rgb = tuple(clamp8(c * 255) for c in colorsys.hls_to_rgb((ph + 0.35) % 1.0, 0.60, max(0.55, ps)))
        else:
            sr, sg, sb = best_sec[1]
            sh, sl, ss = colorsys.rgb_to_hls(sr / 255.0, sg / 255.0, sb / 255.0)
            s_rgb = tuple(clamp8(c * 255) for c in colorsys.hls_to_rgb(sh, max(0.48, min(0.74, sl)), max(0.45, ss)))

        fg_rgb = (
            clamp8(232 * 0.88 + p_rgb[0] * 0.12),
            clamp8(236 * 0.88 + p_rgb[1] * 0.12),
            clamp8(242 * 0.88 + p_rgb[2] * 0.12),
        )

    inactive_rgb = (
        clamp8((surf_rgb[0] + p_rgb[0]) * 0.35),
        clamp8((surf_rgb[1] + p_rgb[1]) * 0.35),
        clamp8((surf_rgb[2] + p_rgb[2]) * 0.35),
    )
    return {
        "bg": to_hex(bg_rgb),
        "surface": to_hex(surf_rgb),
        "fg": to_hex(fg_rgb),
        "primary": to_hex(p_rgb),
        "secondary": to_hex(s_rgb),
        "border_active": to_hex(p_rgb),
        "border_inactive": to_hex(inactive_rgb),
        "wallpaper": path,
    }

print(json.dumps(build_palette(wall)))
PY
)"
    read -r PAL_BG PAL_SURF PAL_FG PAL_PRIM PAL_SEC PAL_ACT PAL_INACT < <(python3 -c '
import json, sys
d = json.loads(sys.argv[1])
print(d["bg"], d["surface"], d["fg"], d["primary"], d["secondary"], d["border_active"], d["border_inactive"])
' "$PALETTE_JSON")

    python3 - "$QS_DIR/minflair/ThemeColors.qml" "$HYPR_DIR/minflair-kitty.conf" "$PALETTE_JSON" <<'PY'
import json
import pathlib
import sys

qml_path, kitty_path, raw = sys.argv[1], sys.argv[2], sys.argv[3]
p = json.loads(raw)
wall_escaped = p.get("wallpaper", "").replace("\\", "\\\\").replace('"', '\\"')

pathlib.Path(qml_path).write_text(
    f'''import QtQuick

QtObject {{
    readonly property color bg: "{p['bg']}"
    readonly property color surface: "{p['surface']}"
    readonly property color fg: "{p['fg']}"
    readonly property color primary: "{p['primary']}"
    readonly property color secondary: "{p['secondary']}"
    readonly property color borderActive: "{p['border_active']}"
    readonly property color borderInactive: "{p['border_inactive']}"
    readonly property string wallpaperPath: "{wall_escaped}"
}}
''',
    encoding="utf-8",
)

pathlib.Path(kitty_path).write_text(
    f'''# Generated by hypr-theme-toggle.sh (minflair profile)
background {p['bg']}
foreground {p['fg']}
cursor {p['primary']}
cursor_text_color {p['bg']}
selection_background {p['primary']}
selection_foreground {p['bg']}
active_border_color {p['border_active']}
inactive_border_color {p['border_inactive']}
url_color {p['secondary']}

color0 {p['bg']}
color8 {p['surface']}
color1 {p['primary']}
color9 {p['primary']}
color2 {p['secondary']}
color10 {p['secondary']}
color3 {p['secondary']}
color11 {p['fg']}
color4 {p['primary']}
color12 {p['primary']}
color5 {p['secondary']}
color13 {p['secondary']}
color6 {p['primary']}
color14 {p['fg']}
color7 {p['fg']}
color15 #ffffff
''',
    encoding="utf-8",
)
PY

    ACTIVE_BORDER="rgb(${PAL_ACT#\#})"
    INACTIVE_BORDER="rgb(${PAL_INACT#\#})"
    GAPS_IN=6
    GAPS_OUT=12
    BORDER_SIZE=2
    ROUNDING=10
    ;;

  carpet)
    mkdir -p "$QS_DIR/carpet"
    cp -f "$THEMES_SRC/carpet/shell.qml" "$QS_DIR/carpet/shell.qml"
    cp -f "$THEMES_SRC/carpet/carpet.svg" "$QS_DIR/carpet/carpet.svg"
    ACTIVE_BORDER="rgb(c98e2c)"
    INACTIVE_BORDER="rgb(1c5c4a)"
    GAPS_IN=4
    GAPS_OUT=10
    BORDER_SIZE=2
    ROUNDING=4
    ;;

  minecraft)
    mkdir -p "$QS_DIR/minecraft"
    cp -f "$THEMES_SRC/minecraft/shell.qml" "$QS_DIR/minecraft/shell.qml"
    ACTIVE_BORDER="rgb(7efc20)"
    INACTIVE_BORDER="rgb(555555)"
    GAPS_IN=4
    GAPS_OUT=8
    BORDER_SIZE=3
    ROUNDING=0
    ;;

  desk)
    mkdir -p "$QS_DIR/desk"
    cp -f "$THEMES_SRC/desk/shell.qml" "$QS_DIR/desk/shell.qml"
    ACTIVE_BORDER="rgb(c89d54)"
    INACTIVE_BORDER="rgb(5c3b24)"
    GAPS_IN=5
    GAPS_OUT=10
    BORDER_SIZE=2
    ROUNDING=6
    ;;
esac

# Generate Hyprland 0.57+ Lua configuration
python3 - "$HYPR_LUA" "$TARGET_THEME" "$KB_LAYOUT" "$TARGET_ACTIVATE" "$ACTIVE_BORDER" "$INACTIVE_BORDER" "$GAPS_IN" "$GAPS_OUT" "$BORDER_SIZE" "$ROUNDING" "$SCRIPT_DIR/hypr-theme-toggle.sh" <<'PY'
import pathlib
import sys

(
    out_path,
    theme,
    kb_layout,
    activate_linux,
    active_border,
    inactive_border,
    gaps_in,
    gaps_out,
    border_size,
    rounding,
    toggle_script,
) = sys.argv[1:12]

toggle_escaped = toggle_script.replace("\\", "\\\\").replace('"', '\\"')

if theme == "persona":
    launch_line = '    hl.exec_cmd(\'qs -c "\' .. profileDir .. \'"\')'
    super_r_bind = 'hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(\'qs -c "\' .. profileDir .. \'" ipc call searchapp toggle\'))'
else:
    launch_line = '    hl.exec_cmd(\'qs -c "\' .. profileDir .. \'"\')'
    super_r_bind = 'hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("krunner"))'

super_l_bind = 'hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(\'qs -p "\' .. cyberLockOverlay .. \'" ipc call lock toggle\'))'

activate_line = ""
if activate_linux == "on":
    activate_line = '\n    hl.exec_cmd(\'qs -p "\' .. activateOverlay .. \'"\')'

lua = f'''-- Hyprland 0.57+ Lua config generated by hypr-theme-toggle.sh (profile: {theme}).
-- Scoped strictly to Hyprland & Quickshell; KDE Plasma configs are never modified.

local home = os.getenv("HYPR_THEME_HOME") or os.getenv("HOME")
local profileDir = home .. "/.config/quickshell/{theme}"
local activateOverlay = home .. "/.config/quickshell/overlays/ActivateLinux.qml"
local cyberLockOverlay = home .. "/.config/quickshell/overlays/CyberLock.qml"
local qmlLocal = home .. "/.local/lib/qt6/qml"
local mainMod = "SUPER"

hl.env("QML2_IMPORT_PATH", qmlLocal)
hl.env("LD_LIBRARY_PATH", qmlLocal .. "/CavaMonitor:" .. qmlLocal)

hl.config({{
    input = {{
        kb_layout = "{kb_layout}",
        follow_mouse = 1,
    }},
    general = {{
        gaps_in = {gaps_in},
        gaps_out = {gaps_out},
        border_size = {border_size},
        layout = "dwindle",
        col = {{
            active_border = "{active_border}",
            inactive_border = "{inactive_border}",
        }},
    }},
    decoration = {{
        rounding = {rounding},
    }},
}})

hl.monitor({{
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
}})

hl.on("hyprland.start", function()
{launch_line}
    hl.exec_cmd('qs -p "' .. cyberLockOverlay .. '"'){activate_line}
end)

-- Theme Switcher & Overlay Toggles
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd('bash "{toggle_escaped}" cycle'))
hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd('bash "{toggle_escaped}" --activate-linux toggle'))
{super_l_bind}
{super_r_bind}

-- Core apps & window controls matching existing KDE workflow
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("dolphin"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({{ action = "toggle" }}))
hl.bind(mainMod .. " + M", hl.dsp.exit())

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), {{ mouse = true }})
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), {{ mouse = true }})

for i = 1, 4 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({{ workspace = i }}))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({{ workspace = i }}))
end
'''

pathlib.Path(out_path).write_text(lua, encoding="utf-8")
PY

# Persist active theme & overlay state
python3 - "$STATE_FILE" "$TARGET_THEME" "$TARGET_ACTIVATE" "$RESOLVED_WALLPAPER" <<'PY'
import json
import pathlib
import sys

state_file, theme, activate, wallpaper = sys.argv[1:5]
data = {
    "active_theme": theme,
    "activate_linux": (activate == "on"),
    "wallpaper": wallpaper,
}
pathlib.Path(state_file).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

# Live compositor / Quickshell process management ONLY when running on real $HOME (never in sandbox tests)
if [[ "$IS_SANDBOX" -eq 0 ]]; then
  if [[ "$ACTION" != "overlay-only" ]] && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    if command -v hyprctl >/dev/null 2>&1; then
      hyprctl reload >/dev/null 2>&1 || true
    fi
    if command -v qs >/dev/null 2>&1; then
      for p in "${THEMES[@]}"; do
        pkill -f "qs -c $QS_DIR/$p" >/dev/null 2>&1 || true
      done
      if [[ "$TARGET_THEME" != "persona" || -f "$QS_DIR/persona/shell.qml" ]]; then
        nohup qs -c "$QS_DIR/$TARGET_THEME" >/dev/null 2>&1 &
      fi
      if ! pgrep -f "qs -p $QS_DIR/overlays/CyberLock.qml" >/dev/null 2>&1; then
        nohup qs -p "$QS_DIR/overlays/CyberLock.qml" >/dev/null 2>&1 &
      fi
    fi
  fi

  if [[ -n "$ACTIVATE_CMD" ]] && [[ -n "${WAYLAND_DISPLAY:-}" || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    if [[ "$TARGET_ACTIVATE" == "on" ]]; then
      if command -v qs >/dev/null 2>&1; then
        pkill -f "qs -p $QS_DIR/overlays/ActivateLinux.qml" >/dev/null 2>&1 || true
        nohup qs -p "$QS_DIR/overlays/ActivateLinux.qml" >/dev/null 2>&1 &
      fi
    else
      pkill -f "qs -p $QS_DIR/overlays/ActivateLinux.qml" >/dev/null 2>&1 || true
    fi
  fi

  command -v notify-send >/dev/null 2>&1 && notify-send -t 1500 "Hyprland Theme" "$TARGET_THEME (ActivateLinux: $TARGET_ACTIVATE)" || true
fi

echo "Active Hyprland theme: $TARGET_THEME (activate_linux=$TARGET_ACTIVATE)"
