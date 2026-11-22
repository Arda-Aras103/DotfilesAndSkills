#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
THEME_SRC="$REPO_ROOT/configs/sddm/cyber-wireframe"
THEME_DST="/usr/share/sddm/themes/cyber-wireframe"
SDDM_DROPIN_DIR="/etc/sddm.conf.d"
SDDM_CONF="$SDDM_DROPIN_DIR/cyber-wireframe.conf"
STATE_FILE="$SDDM_DROPIN_DIR/.cyber-wireframe-state"

detect_greeter_bin() {
  local candidate
  for candidate in sddm-greeter-qt6 /usr/libexec/sddm-greeter-qt6 sddm-greeter /usr/libexec/sddm-greeter; do
    if [[ "$candidate" == /* ]]; then
      if [[ -x "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    elif command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

detect_current_dm() {
  if [[ -L /etc/systemd/system/display-manager.service ]]; then
    local target base
    target="$(readlink /etc/systemd/system/display-manager.service 2>/dev/null || true)"
    base="$(basename "$target")"
    if [[ -n "$base" ]]; then
      printf '%s\n' "$base"
      return 0
    fi
  fi
  if command -v systemctl >/dev/null 2>&1; then
    local svc
    for svc in plasmalogin.service sddm.service gdm.service lightdm.service; do
      if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        printf '%s\n' "$svc"
        return 0
      fi
    done
  fi
  return 1
}

IMAGE_PATH=""
USE_KDE_WALLPAPER=0
RUN_PREVIEW=0
RUN_LOCK_PREVIEW=0
WITH_LOCK=0
LOCK_ONLY=0
SDDM_BACKEND="x11"
GREETER_BIN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      [[ $# -ge 2 ]] || { echo "Missing value for --image" >&2; exit 1; }
      IMAGE_PATH="$2"
      shift 2
      ;;
    --image=*)
      IMAGE_PATH="${1#*=}"
      shift
      ;;
    --kde-wallpaper)
      USE_KDE_WALLPAPER=1
      shift
      ;;
    --preview)
      RUN_PREVIEW=1
      shift
      ;;
    --with-lock)
      WITH_LOCK=1
      shift
      ;;
    --lock-only)
      LOCK_ONLY=1
      WITH_LOCK=1
      shift
      ;;
    --x11-greeter)
      SDDM_BACKEND="x11"
      shift
      ;;
    --wayland-greeter)
      SDDM_BACKEND="wayland"
      shift
      ;;
    --preview-lock)
      WITH_LOCK=1
      RUN_LOCK_PREVIEW=1
      shift
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--image <path> | --kde-wallpaper] [--preview] [--with-lock] [--lock-only] [--x11-greeter | --wayland-greeter] [--preview-lock]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

[[ -d "$THEME_SRC" ]] || { echo "Missing SDDM theme source: $THEME_SRC" >&2; exit 1; }

if [[ -n "$IMAGE_PATH" ]]; then
  IMAGE_PATH="$(python3 -c 'import os,sys; print(os.path.abspath(os.path.expanduser(sys.argv[1])))' "$IMAGE_PATH")"
  [[ -f "$IMAGE_PATH" ]] || { echo "Image file not found: $IMAGE_PATH" >&2; exit 1; }
elif [[ "$USE_KDE_WALLPAPER" -eq 1 ]]; then
  echo "[1/4] Auto-detecting current KDE desktop wallpaper..."
  IMAGE_PATH=$(python3 - <<'PY'
import configparser
import os
import urllib.parse

path = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
if not os.path.exists(path):
    raise SystemExit(0)

cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
cfg.read(path, encoding="utf-8")

desktop_ids = []
for sec in cfg.sections():
    if sec.startswith("Containments][") and sec.count("][") == 1:
        plugin = cfg.get(sec, "plugin", fallback="")
        if plugin in ("org.kde.desktopcontainment", "org.kde.plasma.folder"):
            desktop_ids.append(sec.split("][", 1)[1])

for cid in desktop_ids:
    sec = f"Containments][{cid}][Wallpaper][org.kde.image][General"
    img = cfg.get(sec, "Image", fallback="").strip()
    if img.startswith("file://"):
        img = urllib.parse.unquote(img[7:])
    img = os.path.expanduser(img)
    if img and os.path.isfile(img):
        print(img)
        break
PY
  )
elif [[ -f "$THEME_SRC/login-photo.jpg" ]]; then
  echo "[1/4] Using bundled default SDDM portrait (login-photo.jpg)..."
  IMAGE_PATH="$THEME_SRC/login-photo.jpg"
fi

PALETTE_LINES=""
if [[ "$LOCK_ONLY" -eq 0 ]]; then
echo "[2/4] Ensuring SDDM packages/service and installing cyber-wireframe theme into $THEME_DST..."
INSTALLED_SDDM=0
PREV_DM=""
if sudo test -f "$STATE_FILE"; then
  STATE_CONTENT="$(sudo cat "$STATE_FILE" 2>/dev/null || true)"
  INSTALLED_SDDM="$(printf '%s\n' "$STATE_CONTENT" | awk -F= '/^INSTALLED_SDDM=/{print $2; exit}')"
  PREV_DM="$(printf '%s\n' "$STATE_CONTENT" | awk -F= '/^PREV_DM=/{print $2; exit}')"
  INSTALLED_SDDM="${INSTALLED_SDDM:-0}"
fi

GREETER_BIN="$(detect_greeter_bin || true)"
if [[ -z "$GREETER_BIN" ]]; then
  echo "  -> No SDDM greeter binary found (Fedora 44+ defaults to plasma-login-manager); installing SDDM..."
  if [[ "$SDDM_BACKEND" == "x11" ]]; then
    if ! sudo dnf install -y sddm sddm-kcm sddm-x11; then
      echo "  -> sddm-x11 unavailable; falling back to sddm-wayland-plasma..."
      sudo dnf install -y sddm sddm-kcm sddm-wayland-plasma
    fi
  else
    sudo dnf install -y sddm sddm-kcm sddm-wayland-plasma
  fi
  INSTALLED_SDDM=1
  GREETER_BIN="$(detect_greeter_bin || true)"
elif [[ "$SDDM_BACKEND" == "x11" ]] && rpm -q sddm-wayland-plasma >/dev/null 2>&1 && ! rpm -q sddm-x11 >/dev/null 2>&1; then
  echo "  -> Swapping SDDM greeter backend from sddm-wayland-plasma to sddm-x11 (desktop session remains Wayland)..."
  sudo dnf swap -y sddm-wayland-plasma sddm-x11 || echo "  -> Keeping existing sddm-wayland-plasma."
fi

CURRENT_DM="$(detect_current_dm || true)"
if [[ "$CURRENT_DM" != "sddm.service" ]]; then
  if [[ -z "$PREV_DM" && -n "$CURRENT_DM" ]]; then
    PREV_DM="$CURRENT_DM"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    echo "  -> Switching display manager to sddm.service (previous: ${PREV_DM:-none})..."
    sudo systemctl disable plasmalogin.service >/dev/null 2>&1 || true
    sudo systemctl enable --force sddm.service
  fi
fi

sudo install -d -m 755 "$SDDM_DROPIN_DIR"
printf 'INSTALLED_SDDM=%s\nPREV_DM=%s\n' "$INSTALLED_SDDM" "$PREV_DM" | sudo tee "$STATE_FILE" >/dev/null
sudo chmod 644 "$STATE_FILE"

sudo install -d -m 755 "$THEME_DST"
for f in Main.qml theme.conf metadata.desktop default-frame.svg; do
  sudo install -m 644 "$THEME_SRC/$f" "$THEME_DST/$f"
done
if [[ -f "$THEME_SRC/login-photo.jpg" ]]; then
  sudo install -m 644 "$THEME_SRC/login-photo.jpg" "$THEME_DST/login-photo.jpg"
fi

if [[ "$GREETER_BIN" == *qt6* ]]; then
  if ! sudo grep -qE '^QtVersion=' "$THEME_DST/metadata.desktop" 2>/dev/null; then
    printf 'QtVersion=6\n' | sudo tee -a "$THEME_DST/metadata.desktop" >/dev/null
  fi
  echo "  -> Detected Qt6 greeter ($GREETER_BIN); enabled QtVersion=6"
elif [[ -n "$GREETER_BIN" ]]; then
  echo "  -> Detected greeter ($GREETER_BIN); keeping QtVersion unset for sddm-greeter compatibility"
fi

USER_CONF="$THEME_DST/theme.conf.user"
if sudo test -f "$USER_CONF" && ! sudo test -f "$USER_CONF.rice.bak"; then
  sudo cp -f "$USER_CONF" "$USER_CONF.rice.bak"
fi

sudo rm -f "$THEME_DST"/custom-frame.*
if [[ -n "$IMAGE_PATH" && -f "$IMAGE_PATH" ]]; then
  EXT="${IMAGE_PATH##*.}"
  EXT="${EXT,,}"
  [[ -n "$EXT" ]] || EXT="png"
  DEST_IMG_NAME="custom-frame.$EXT"
  sudo install -m 644 "$IMAGE_PATH" "$THEME_DST/$DEST_IMG_NAME"
fi
fi

if [[ -n "$IMAGE_PATH" && -f "$IMAGE_PATH" ]]; then
  PALETTE_LINES="$(python3 - "$IMAGE_PATH" <<'PY'
import colorsys
import pathlib
import struct
import sys
import zlib

img_path = pathlib.Path(sys.argv[1])

def clamp8(v: float) -> int:
    return max(0, min(255, int(round(v))))

def to_hex(rgb: tuple[int, int, int]) -> str:
    return f"#{clamp8(rgb[0]):02x}{clamp8(rgb[1]):02x}{clamp8(rgb[2]):02x}"

def hls_hex(h: float, l: float, s: float) -> str:
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return to_hex((r * 255.0, g * 255.0, b * 255.0))

def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c

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
            total = min(w * h, len(raw) // 3)
            step = max(1, total // 8000)
            return [
                (raw[i * 3] * 255 // maxv, raw[i * 3 + 1] * 255 // maxv, raw[i * 3 + 2] * 255 // maxv)
                for i in range(0, total, step)
            ]
    elif data.startswith(b"P3"):
        lines: list[str] = []
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
            width, height, bit_depth, color_type, _c, _f, interlace = struct.unpack(">IIBBBBB", chunk[:13])
        elif ctype == b"PLTE":
            plte = chunk
        elif ctype == b"IDAT":
            idat.extend(chunk)
        elif ctype == b"IEND":
            break
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type)
    if width <= 0 or height <= 0 or interlace != 0 or bit_depth not in (8, 16) or channels is None:
        return []
    raw = zlib.decompress(bytes(idat))
    bw = bit_depth // 8
    bpp = channels * bw
    stride = width * bpp
    if len(raw) < (stride + 1) * height:
        return []
    pixels: list[tuple[int, int, int]] = []
    y_step, x_step = max(1, height // 120), max(1, width // 120)
    prev = bytearray(stride)
    for y in range(height):
        rs = y * (stride + 1)
        ft = raw[rs]
        src = raw[rs + 1:rs + 1 + stride]
        cur = bytearray(stride)
        if ft == 0:
            cur[:] = src
        elif ft == 1:
            for i in range(stride):
                cur[i] = (src[i] + (cur[i - bpp] if i >= bpp else 0)) & 0xFF
        elif ft == 2:
            for i in range(stride):
                cur[i] = (src[i] + prev[i]) & 0xFF
        elif ft == 3:
            for i in range(stride):
                cur[i] = (src[i] + (((cur[i - bpp] if i >= bpp else 0) + prev[i]) >> 1)) & 0xFF
        elif ft == 4:
            for i in range(stride):
                cur[i] = (src[i] + paeth(cur[i - bpp] if i >= bpp else 0, prev[i], prev[i - bpp] if i >= bpp else 0)) & 0xFF
        else:
            return []
        if y % y_step == 0:
            for x in range(0, width, x_step):
                off = x * bpp
                if color_type in (2, 6):
                    pixels.append((cur[off], cur[off + bw], cur[off + 2 * bw]))
                elif color_type in (0, 4):
                    v = cur[off]
                    pixels.append((v, v, v))
                elif color_type == 3:
                    idx = cur[off] * 3
                    if idx + 2 < len(plte):
                        pixels.append((plte[idx], plte[idx + 1], plte[idx + 2]))
        prev = cur
    return pixels

def sample_jpeg_dc(data: bytes) -> list[tuple[int, int, int]]:
    if not data.startswith(b"\xff\xd8"):
        return []
    i = 2
    n = len(data)
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
                tq = seg[p] & 0x0F
                prec = seg[p] >> 4
                p += 1
                dqt[tq] = seg[p] if prec == 0 else int.from_bytes(seg[p:p + 2], "big")
                p += 64 * (2 if prec else 1)
        elif m == 0xDD and len(seg) >= 2:
            dri = int.from_bytes(seg[:2], "big")
        elif m in (0xC0, 0xC2) and len(seg) >= 6:
            h_px = int.from_bytes(seg[1:3], "big")
            w_px = int.from_bytes(seg[3:5], "big")
            nf = seg[5]
            comps = [(seg[6 + 3 * c], seg[7 + 3 * c] >> 4, seg[7 + 3 * c] & 0x0F, seg[8 + 3 * c]) for c in range(nf)]
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
            ah_al = seg[3 + 2 * ns]
            al = ah_al & 0x0F
            entropy_pos = i + seg_len
            break
        i += seg_len

    if sof is None or entropy_pos < 0 or not scan_comps:
        return []
    sof_marker, w_px, h_px, comps = sof
    if not all((0, td) in dht for _, td, _ in scan_comps):
        return []

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
            else:
                break
        raw.append(b)
        p += 1

    nbits = len(raw) * 8
    bit_idx = 0

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
    total_mcus = mcus_x * mcus_y

    preds = {cid: 0 for cid, _, _, _ in comps}
    pixels: list[tuple[int, int, int]] = []
    rst_idx = 0

    for mcu_i in range(total_mcus):
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
            r_px = clamp8(y_val + 1.402 * cr_val)
            g_px = clamp8(y_val - 0.344136 * cb_val - 0.714136 * cr_val)
            b_px = clamp8(y_val + 1.772 * cb_val)
            pixels.append((r_px, g_px, b_px))
    return pixels

def sample_pixels(path: pathlib.Path) -> list[tuple[int, int, int]]:
    try:
        from PIL import Image  # fastest full decode if Pillow is present
        with Image.open(path) as im:
            im = im.convert("RGB")
            im.thumbnail((128, 128))
            return list(im.getdata())
    except Exception:
        pass
    data = path.read_bytes()
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        px = sample_png(data)
        if px:
            return px
    if data.startswith((b"P6", b"P3")):
        px = sample_ppm(data)
        if px:
            return px
    if data.startswith(b"\xff\xd8"):
        return sample_jpeg_dc(data)
    return []

def srgb_rel_lum(hex_col: str) -> float:
    h = hex_col.lstrip("#")
    vals = []
    for k in (0, 2, 4):
        c = int(h[k:k + 2], 16) / 255.0
        vals.append(c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * vals[0] + 0.7152 * vals[1] + 0.0722 * vals[2]

def contrast_ratio(c1: str, c2: str) -> float:
    l1, l2 = srgb_rel_lum(c1), srgb_rel_lum(c2)
    if l2 > l1:
        l1, l2 = l2, l1
    return (l1 + 0.05) / (l2 + 0.05)

pixels = sample_pixels(img_path)
if not pixels:
    palette = {
        "BackgroundColor": "#f5eccd",
        "ForegroundColor": "#282726",
        "PillColor": "#cfc7ab",
        "AccentShade": "#eadbb6",
        "WireframeColor": "#282726",
        "ErrorColor": "#8c2f27",
    }
else:
    n_px = len(pixels)
    lums = [(0.299 * r + 0.587 * g + 0.114 * b) / 255.0 for r, g, b in pixels]
    mean_lum = sum(lums) / n_px
    dark_ratio = sum(1 for x in lums if x < 0.28) / n_px
    is_dark = (mean_lum < 0.48) or (dark_ratio >= 0.45)

    # Extract warm/chromatic hue from midtones so pure black/white clipping doesn't skew tint
    sin_h = cos_h = sat_acc = w_acc = 0.0
    import math
    for (r, g, b), lum in zip(pixels, lums):
        h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
        mid_w = 1.0 if 0.10 <= lum <= 0.86 else 0.15
        wt = mid_w * (0.25 + s * 2.5)
        ang = h * 2.0 * math.pi
        cos_h += math.cos(ang) * wt
        sin_h += math.sin(ang) * wt
        sat_acc += s * wt
        w_acc += wt

    if w_acc > 0:
        base_hue = (math.atan2(sin_h, cos_h) / (2.0 * math.pi)) % 1.0
        base_sat = sat_acc / w_acc
    else:
        base_hue, base_sat = 0.11, 0.18

    if is_dark:
        bg_sat = min(0.22, max(0.05, base_sat * 0.8))
        fg_sat = min(0.32, max(0.14, base_sat * 1.45 + 0.08))
        wire_sat = min(0.36, max(0.10, base_sat * 1.4))
        bg = hls_hex(base_hue, 0.04, bg_sat)
        fg_l = 0.90
        fg = hls_hex(base_hue, fg_l, fg_sat)
        while contrast_ratio(bg, fg) < 7.5 and fg_l < 0.97:
            fg_l += 0.02
            fg = hls_hex(base_hue, fg_l, fg_sat)
        pill = hls_hex(base_hue, 0.105, min(0.26, bg_sat + 0.04))
        shade = hls_hex(base_hue, 0.08, min(0.22, bg_sat + 0.02))
        wire = hls_hex(base_hue, 0.62, wire_sat)
        err = "#d94a3d"
    else:
        bg_sat = min(0.45, max(0.15, base_sat * 1.3 + 0.10))
        fg_sat = min(0.22, max(0.04, base_sat * 0.4))
        bg = hls_hex(base_hue, 0.89, bg_sat)
        fg_l = 0.15
        fg = hls_hex(base_hue, fg_l, fg_sat)
        while contrast_ratio(bg, fg) < 7.5 and fg_l > 0.05:
            fg_l -= 0.02
            fg = hls_hex(base_hue, fg_l, fg_sat)
        pill = hls_hex(base_hue, 0.76, min(0.36, bg_sat * 0.85))
        shade = hls_hex(base_hue, 0.83, min(0.42, bg_sat * 0.95))
        wire = hls_hex(base_hue, 0.22, min(0.30, base_sat + 0.05))
        err = "#8c2f27"

    palette = {
        "BackgroundColor": bg,
        "ForegroundColor": fg,
        "PillColor": pill,
        "AccentShade": shade,
        "WireframeColor": wire,
        "ErrorColor": err,
    }

for k, v in palette.items():
    print(f"{k}={v}")
PY
)"
fi

if [[ "$LOCK_ONLY" -eq 0 ]]; then
if [[ -n "$IMAGE_PATH" && -f "$IMAGE_PATH" ]]; then
  {
    printf '[General]\nCustomImage=%s\n' "$DEST_IMG_NAME"
    printf '%s\n' "$PALETTE_LINES"
  } | sudo tee "$USER_CONF" >/dev/null
  echo "  -> Configured CustomImage=$DEST_IMG_NAME (from $IMAGE_PATH)"
  echo "  -> Extracted photo-adaptive palette:"
  printf '%s\n' "$PALETTE_LINES" | sed 's/^/     /'
else
  printf '[General]\nCustomImage=default-frame.svg\n' | sudo tee "$USER_CONF" >/dev/null
  echo "  -> Using fallback CustomImage=default-frame.svg"
fi
sudo chmod 644 "$USER_CONF"

echo "[3/4] Updating SDDM config ($SDDM_CONF)..."
sudo install -d -m 755 "$SDDM_DROPIN_DIR"
if sudo test -f "$SDDM_CONF"; then
  if ! sudo test -f "$SDDM_CONF.rice.bak" && ! sudo grep -qE '^[[:space:]]*Current=cyber-wireframe$' "$SDDM_CONF" 2>/dev/null; then
    sudo cp -f "$SDDM_CONF" "$SDDM_CONF.rice.bak"
  fi
fi
printf '[General]\nInputMethod=\n\n[Theme]\nCurrent=cyber-wireframe\n' | sudo tee "$SDDM_CONF" >/dev/null
sudo chmod 644 "$SDDM_CONF"

# Back up and override any existing SDDM drop-in or /etc/sddm.conf that explicitly sets Current=
for cfg_file in /etc/sddm.conf "$SDDM_DROPIN_DIR"/*.conf; do
  sudo test -f "$cfg_file" || continue
  [[ "$cfg_file" == "$SDDM_CONF" ]] && continue
  if sudo grep -qE '^[[:space:]]*Current=' "$cfg_file" 2>/dev/null; then
    if ! sudo test -f "$cfg_file.rice.bak"; then
      sudo cp -f "$cfg_file" "$cfg_file.rice.bak"
    fi
    sudo python3 - "$cfg_file" <<'PY'
import pathlib
import re
import sys

p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
updated = re.sub(r"(?m)^[ \t]*Current=.*$", "Current=cyber-wireframe", text)
p.write_text(updated, encoding="utf-8")
PY
  fi
done

echo "[4/5] Applying SELinux context (if available)..."
if command -v restorecon >/dev/null 2>&1; then
  sudo restorecon -R "$THEME_DST" "$SDDM_CONF" >/dev/null 2>&1 || true
fi
fi

if [[ "$WITH_LOCK" -eq 1 ]]; then
echo "[5/5] Updating KDE Win+L lock screen (kscreenlockerrc) to match Cyber-Portrait theme..."
LOCK_WALL_DIR="$HOME/.local/share/wallpapers"
LOCK_SVG="$LOCK_WALL_DIR/cyber-lockscreen.svg"
LOCK_PNG="$LOCK_WALL_DIR/cyber-lockscreen.png"
LOCK_RC="$HOME/.config/kscreenlockerrc"
mkdir -p "$LOCK_WALL_DIR" "$(dirname "$LOCK_RC")"

if [[ -f "$LOCK_RC" ]]; then
  if [[ ! -f "$LOCK_RC.rice.bak" ]]; then
    cp -f "$LOCK_RC" "$LOCK_RC.rice.bak"
  fi
else
  touch "$LOCK_RC.rice.created"
fi

LOCK_BG="#0c0a08"
LOCK_FG="#eee5dd"
LOCK_SHADE="#191410"
LOCK_WIRE="#c19c7b"
if [[ -n "${PALETTE_LINES:-}" ]]; then
  LOCK_BG="$(printf '%s\n' "$PALETTE_LINES" | awk -F= '/^BackgroundColor=/{print $2; exit}')"
  LOCK_FG="$(printf '%s\n' "$PALETTE_LINES" | awk -F= '/^ForegroundColor=/{print $2; exit}')"
  LOCK_SHADE="$(printf '%s\n' "$PALETTE_LINES" | awk -F= '/^AccentShade=/{print $2; exit}')"
  LOCK_WIRE="$(printf '%s\n' "$PALETTE_LINES" | awk -F= '/^WireframeColor=/{print $2; exit}')"
  LOCK_BG="${LOCK_BG:-#0c0a08}"
  LOCK_FG="${LOCK_FG:-#eee5dd}"
  LOCK_SHADE="${LOCK_SHADE:-#191410}"
  LOCK_WIRE="${LOCK_WIRE:-#c19c7b}"
fi

LOCK_IMG_SRC="${IMAGE_PATH:-$THEME_SRC/login-photo.jpg}"
[[ -f "$LOCK_IMG_SRC" ]] || LOCK_IMG_SRC="$THEME_SRC/default-frame.svg"

python3 - "$LOCK_SVG" "$LOCK_IMG_SRC" "$LOCK_BG" "$LOCK_FG" "$LOCK_SHADE" "$LOCK_WIRE" <<'PY'
import base64
import html
import pathlib
import sys

out_svg, src_img, bg, fg, shade, wire = [sys.argv[i] for i in range(1, 7)]
img_bytes = pathlib.Path(src_img).read_bytes()
ext = pathlib.Path(src_img).suffix.lower()
mime = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".svg": "image/svg+xml",
}.get(ext, "image/jpeg")
b64 = base64.b64encode(img_bytes).decode("ascii")
data_uri = f"data:{mime};base64,{b64}"

# Editorial Portrait Showcase on right matching Main.qml (1920x1080)
fw, fh = 660, 640
fx = 1920 - 96 - fw
fy = (1080 - fh) // 2

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="1920" height="1080">
  <defs>
    <clipPath id="portraitClip">
      <rect x="{fx + 12}" y="{fy + 12}" width="{fw - 24}" height="{fh - 24}" rx="2"/>
    </clipPath>
  </defs>
  <rect width="1920" height="1080" fill="{html.escape(bg)}"/>
  <text x="28" y="38" fill="{html.escape(fg)}" fill-opacity="0.45" font-family="JetBrainsMono Nerd Font, monospace" font-size="11" letter-spacing="2.5">SYSTEM // ACCESS</text>

  <!-- Offset layered shadow / accent card -->
  <rect x="{fx + 14}" y="{fy + 14}" width="{fw - 14}" height="{fh - 14}" rx="4" fill="{html.escape(shade)}" fill-opacity="0.65" stroke="{html.escape(wire)}" stroke-width="1"/>

  <!-- Main portrait frame -->
  <rect x="{fx}" y="{fy}" width="{fw - 14}" height="{fh - 14}" rx="4" fill="{html.escape(bg)}" stroke="{html.escape(wire)}" stroke-width="1.4"/>
  <image href="{data_uri}" x="{fx + 12}" y="{fy + 12}" width="{fw - 38}" height="{fh - 38}" preserveAspectRatio="xMaxYMid slice" clip-path="url(#portraitClip)"/>

  <!-- Bottom caption strip -->
  <rect x="{fx + 12}" y="{fy + fh - 56}" width="{fw - 38}" height="30" fill="{html.escape(bg)}" fill-opacity="0.84"/>
  <line x1="{fx + 12}" y1="{fy + fh - 56}" x2="{fx + fw - 26}" y2="{fy + fh - 56}" stroke="{html.escape(wire)}" stroke-opacity="0.45" stroke-width="1"/>
  <text x="{fx + 22}" y="{fy + fh - 37}" fill="{html.escape(fg)}" fill-opacity="0.90" font-family="JetBrainsMono Nerd Font, monospace" font-size="10" font-weight="bold" letter-spacing="2">CYBER // PORTRAIT</text>

  <!-- Clean L-corner viewfinder brackets + subtle partial orbital arc -->
  <g stroke="{html.escape(wire)}" stroke-width="1.8" stroke-opacity="0.85" fill="none">
    <path d="M {fx+10} {fy+34} L {fx+10} {fy+10} L {fx+34} {fy+10}"/>
    <path d="M {fx+fw-48} {fy+10} L {fx+fw-24} {fy+10} L {fx+fw-24} {fy+34}"/>
    <path d="M {fx+10} {fy+fh-48} L {fx+10} {fy+fh-24} L {fx+34} {fy+fh-24}"/>
    <path d="M {fx+fw-48} {fy+fh-24} L {fx+fw-24} {fy+fh-24} L {fx+fw-24} {fy+fh-48}"/>
  </g>
  <circle cx="{fx + int(fw * 0.76)}" cy="{fy + int(fh * 0.28)}" r="{int(min(fw, fh) * 0.30)}" fill="none" stroke="{html.escape(wire)}" stroke-width="1.2" stroke-opacity="0.30" stroke-dasharray="190 420"/>
</svg>
'''
pathlib.Path(out_svg).write_text(svg, encoding="utf-8")
PY

LOCK_TARGET="$LOCK_SVG"
rm -f "$LOCK_PNG"
if command -v rsvg-convert >/dev/null 2>&1 && rsvg-convert -w 1920 -h 1080 "$LOCK_SVG" -o "$LOCK_PNG" >/dev/null 2>&1 && [[ -s "$LOCK_PNG" ]]; then
  LOCK_TARGET="$LOCK_PNG"
elif command -v resvg >/dev/null 2>&1 && resvg -w 1920 -h 1080 "$LOCK_SVG" "$LOCK_PNG" >/dev/null 2>&1 && [[ -s "$LOCK_PNG" ]]; then
  LOCK_TARGET="$LOCK_PNG"
elif command -v magick >/dev/null 2>&1 && magick "$LOCK_SVG" "$LOCK_PNG" >/dev/null 2>&1 && [[ -s "$LOCK_PNG" ]]; then
  LOCK_TARGET="$LOCK_PNG"
elif command -v ffmpeg >/dev/null 2>&1 && ffmpeg -y -i "$LOCK_SVG" -frames:v 1 "$LOCK_PNG" >/dev/null 2>&1 && [[ -s "$LOCK_PNG" ]]; then
  LOCK_TARGET="$LOCK_PNG"
fi

python3 - "$LOCK_RC" "$LOCK_TARGET" <<'PY'
import configparser
import os
import sys

rc_path, img_path = sys.argv[1], sys.argv[2]
cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
if os.path.exists(rc_path):
    cfg.read(rc_path, encoding="utf-8")

if not cfg.has_section("Greeter"):
    cfg.add_section("Greeter")
cfg.set("Greeter", "WallpaperPlugin", "org.kde.image")

sec = "Greeter][Wallpaper][org.kde.image][General"
if not cfg.has_section(sec):
    cfg.add_section(sec)
uri = f"file://{img_path}"
cfg.set(sec, "Image", uri)
cfg.set(sec, "PreviewImage", uri)

with open(rc_path, "w", encoding="utf-8") as fh:
    cfg.write(fh, space_around_delimiters=False)
PY
echo "  -> Configured Win+L lock screen wallpaper: $LOCK_TARGET"
fi

LOCK_GREETER=""
for cand in /usr/libexec/kscreenlocker_greet kscreenlocker_greet; do
  if [[ "$cand" == /* ]]; then
    [[ -x "$cand" ]] && { LOCK_GREETER="$cand"; break; }
  elif command -v "$cand" >/dev/null 2>&1; then
    LOCK_GREETER="$(command -v "$cand")"
    break
  fi
done

echo ""
if [[ "$LOCK_ONLY" -eq 1 ]]; then
  echo "Installed Cyber-Portrait Win+L lock screen (display manager untouched)."
  echo "Revert cleanly at any time with:"
  echo "  bash $SCRIPT_DIR/sddm-cyber-revert.sh --lock-only"
else
  echo "Installed cyber-wireframe SDDM theme & Cyber-Portrait Win+L lock screen."
  if [[ -n "$GREETER_BIN" ]]; then
    echo "Preview SDDM login safely without logging out:"
    echo "  $GREETER_BIN --test-mode --theme $THEME_DST"
  fi
fi
if [[ -n "$LOCK_GREETER" ]]; then
  echo "Preview KDE Win+L lock screen safely:"
  echo "  $LOCK_GREETER --testing"
fi
if [[ "$LOCK_ONLY" -eq 0 ]]; then
  if [[ "$RUN_PREVIEW" -eq 1 && -n "$GREETER_BIN" ]]; then
    echo "Launching SDDM preview..."
    "$GREETER_BIN" --test-mode --theme "$THEME_DST"
  elif [[ "$RUN_PREVIEW" -eq 1 && -z "$GREETER_BIN" ]]; then
    echo "Error: Cannot launch --preview because no sddm-greeter binary was found." >&2
    exit 1
  fi
fi
if [[ "$RUN_LOCK_PREVIEW" -eq 1 ]]; then
  if [[ -n "$LOCK_GREETER" ]]; then
    echo "Launching KDE Win+L lock screen preview..."
    "$LOCK_GREETER" --testing
  else
    echo "Warning: kscreenlocker_greet not found for --preview-lock; test live with Win+L." >&2
  fi
fi
