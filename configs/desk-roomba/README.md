# Desk Roomba (`desk-roomba`)

Transparent **Wayland Layer-Shell** desktop robot vacuum for **Fedora Linux + KDE Plasma (Wayland)**.

When clicked (or triggered automatically with `--auto-watch`), the Roomba leaves its charging dock in the bottom-left corner, renders floating file cards for loose clutter in `~/Desktop`, shines a directional headlight cone, sucks up each file with a `"nom!"` animation, and safely moves real files into categorized folders under `~/Desktop/Organized/`.

---

## Architecture

- **Window Surface:** Fullscreen transparent `Gtk.ApplicationWindow` anchored to all four edges via `Gtk4LayerShell` (`zwlr_layer_shell_v1`, natively supported by KWin on KDE Plasma Wayland).
- **Pre-load Hook:** Pre-loads `libgtk4-layer-shell.so.0` with `ctypes.RTLD_GLOBAL` before importing `gi` so `gtk4-layer-shell` interposes `libwayland-client` prior to GTK4 initialization.
- **Click-Through Masking:** Dynamically computes a `cairo.Region` containing only the charging dock (`90x90`) and the Roomba's current bounding box (`110x125`), passing it to `Gdk.Surface.set_input_region()`. Everything else on the screen stays 100% click-through.
- **Zero-Idle-CPU Loop:** Runs the 60 FPS `GLib.timeout_add(16, ...)` loop only while moving/animating. When parked on the dock, the animation timer stops completely.

---

## Mouse Controls (On Dock or Roomba)

| Action | Behavior |
| :--- | :--- |
| **Left-click** | Sweeps loose files from `--dir` into `--dest`. If the directory is already clean, runs a harmless **Demo Sweep**. |
| **Right-click** | Runs an explicit **Demo Sweep** without touching real files. |
| **Middle-click** | Quits the overlay cleanly. |
| **Shift + Middle-click** | Opens the `Organized/` destination folder via `xdg-open`. |

---

## File Categories & Safety Rules

- **Categories:** `Screenshots`, `Documents`, `Images`, `Archives`, `Code`, `Media`, `Other`.
- **Skipped automatically:** Directories, symlinks, hidden files (`.` prefix), `.desktop` launchers, and active downloads (`.part`, `.crdownload`, `.tmp`).
- **No overwrites:** Colliding filenames are renamed automatically (`file_1.pdf`, `file_2.pdf`, ...).
- **Undo log:** Every move batch is recorded in `~/.local/share/desk-roomba/history.jsonl`.

---

## CLI Options

| Flag | Default | Description |
| :--- | :--- | :--- |
| `--dir PATH` | `~/Desktop` | Watched/swept directory (repeatable, e.g., `--dir ~/Desktop --dir ~/Downloads`). |
| `--dest PATH` | `~/Desktop/Organized` | Root folder where categorized subdirectories are created. |
| `--layer {background,bottom,top,overlay}` | `top` | Wayland layer. Use `bottom` to sit above wallpaper/desktop and below open windows. |
| `--demo` | `false` | Launch and immediately play a safe demo sweep. |
| `--sweep` | `false` | Launch and immediately sweep real loose files. |
| `--auto-watch` | `false` | Poll `--dir` while parked and sweep new files older than 3 seconds. |
| `--watch-interval SECS` | `4` | Polling interval in seconds for `--auto-watch`. |
| `--speed PX_PER_SEC` | `340.0` | Roomba movement speed. |
| `--undo` | `false` | Restore all files from the latest sweep batch and exit. |

---

## Fedora Commands (Copy-Paste Ready)

**1. Install runtime dependencies:**
```bash
sudo dnf install -y gtk4-layer-shell python3-gobject python3-cairo
```

**2. Test immediately with safe visual demo:**
```bash
python3 -B ~/agy-docker/workspace/configs/desk-roomba/desk_roomba.py --demo
```

**3. Run as persistent desktop layer (under normal windows):**
```bash
python3 -B ~/agy-docker/workspace/configs/desk-roomba/desk_roomba.py --layer bottom --auto-watch
```

**4. Install app launcher & Plasma autostart shortcut:**
```bash
install -Dm644 ~/agy-docker/workspace/configs/desk-roomba/desk-roomba.desktop ~/.local/share/applications/desk-roomba.desktop && install -Dm644 ~/agy-docker/workspace/configs/desk-roomba/desk-roomba.desktop ~/.config/autostart/desk-roomba.desktop
```

**5. Undo the last sweep batch:**
```bash
python3 -B ~/agy-docker/workspace/configs/desk-roomba/desk_roomba.py --undo
```

---

## Clean Uninstall

```bash
pkill -f desk_roomba.py || true; rm -rf ~/.local/share/desk-roomba ~/.local/share/applications/desk-roomba.desktop ~/.config/autostart/desk-roomba.desktop && sudo dnf remove -y gtk4-layer-shell && sudo dnf autoremove -y
```
