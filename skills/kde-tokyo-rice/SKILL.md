---
name: kde-tokyo-rice
description: KDE Plasma 6 Wayland Hyprland-style desktop ricing and Tokyo Night theme unification across KWin panels GTK Flatpak Kitty Zed Zen Browser TUI tools Rust egui apps and WebExtensions with paired rice and revert scripts. Triggers include rice, tokyo night, kde rice, plasma rice, kwin kural, baslik cubugu kaldir, no titlebar, panel colorizer, zen rice, zed rice, userChrome.css, kquicklook tema, tema uygula, tema geri al, plymouth tema, boot ekrani, lock screen, kilit ekrani, sddm tema.
user-invocable: true
metadata:
  type: workflow
  version: "1.3"
---

# KDE Plasma 6 Wayland & Tokyo Night Rice

Design, maintain, and synchronize a Hyprland-inspired **KDE Plasma 6 (Wayland)** desktop and unified **Tokyo Night** visual theme across system configs, terminal/editor tooling, native Rust (`egui`) apps, GTK/Flatpak dialogs, and Zen Browser extensions — always shipping paired, idempotent `*-rice.sh` and `*-revert.sh` scripts.

## When

Use when adding a themed config, adjusting Plasma 6 / KWin Wayland rules, theming native apps or Zen WebExtensions, updating `*-rice.sh` / `*-revert.sh` pairs, or troubleshooting ricing regressions (focus stealing, missing Dolphin menus, JSONC parse errors, or Flatpak/container permissions).

## Workflow

### 1. Canonical Tokyo Night Palette
| Token Role | Hex | `egui::Color32` RGB |
|---|---|---|
| Canvas / Background | `#1a1b26` | `(26, 27, 38)` |
| Surface / Panel / Code BG | `#16161e` | `(22, 22, 30)` |
| Card / Input / Button BG | `#24283b` | `(36, 40, 59)` |
| Active / Selected Surface | `#283457` (hover `#33467c`) | `(40, 52, 87)` / `(51, 70, 124)` |
| Borders (Subtle / Strong) | `#2f3549` / `#3b4261` | `(47, 53, 73)` / `(59, 66, 97)` |
| Text (Primary / Secondary / Muted) | `#c0caf5` / `#a9b1d6` / `#565f89` | `(192, 202, 245)` / `(169, 177, 214)` / `(86, 95, 137)` |
| Accent Blue / Hover Blue | `#7aa2f7` / `#89b4fa` | `(122, 162, 247)` |
| Cyan / Green / Amber / Red | `#7dcfff` / `#9ece6a` / `#e0af68` / `#f7768e` | `(125, 207, 255)` / `(158, 206, 106)` / `(224, 175, 104)` / `(247, 118, 142)` |

### 2. KDE Plasma 6 (Wayland) & KXMLGUI Rules
- **Window Rules (`~/.config/kwinrulesrc`):** Plasma 6 uses `[General] Order=` (or legacy `rules=`/`count=`) and `decorationpolicy=none` + `decorationpolicyrule=2` (fallback `noborder=true`). Match by `Description` or stable section ID; never overwrite existing rules blindly.
- **Wayland Focus & Always-On-Top (`kquicklook`):** Set `wmclassmatch=1`, `fsplevel=0` (`fsplevelrule=2`), `acceptfocus=true` (`acceptfocusrule=2`), `above=true` (`aboverule=2`), and `skiptaskbar=true` (`skiptaskbarrule=2`), then reload via `busctl` or `dbus-send` `org.kde.KWin.reconfigure`.
- **KXMLGUI Shortcut Overrides (`kxmlgui5` / `kxmlgui6` `dolphinui.rc`):** Shortcut-only overrides MUST keep `version="1"` (and omit `<MenuBar>`/`<ToolBar>`) so Dolphin merges `<ActionProperties>` without wiping default menus/toolbars.
- **Panel Island & Themes:** Floating 34px top panel via Plasma Scripting (`luisbocanegra.panel.colorizer` with `hideWidget=true`, `org.kde.plasma.pager` in `1x4` desktop mode, 24h `org.kde.plasma.digitalclock`). Apply schemes via `plasma-apply-colorscheme`.
- **Boot & Lock Themes (Plymouth / SDDM):** Stage boot themes under `configs/plymouth/<theme>/` with paired `scripts/plymouth-<theme>-{rice,revert}.sh` (revert restores `bgrt` via `plymouth-set-default-theme -R`). For SDDM/lock scripts, support `--lock-only` when keeping Fedora native `plasmalogin.service`, default greeter to `sddm-x11` on NVIDIA Wayland, and hide virtual-keyboard buttons in QML.

### 3. Editors, Browsers & GTK/Flatpak Integration
- **Zed (`~/.config/zed/settings.json`):** Strip JSONC comments (`//`, `/* */`) and trailing commas before `json.loads`, then merge `One Dark`, `JetBrainsMono Nerd Font`, and `experimental.theme_overrides` without clobbering user preferences.
- **Zen Browser (`profiles.ini` + CSS + `.xpi`):** Discover profiles across `~/.zen`, `~/.var/app/app.zen_browser.zen/.zen`, and `~/.var/app/io.github.zen_browser.zen/.zen`. Wrap `user.js` and `chrome/{userChrome,userContent}.css` rules in `>>> rice-zen >>>` / `<<< rice-zen <<<` markers. Repackage WebExtensions via Python `zipfile` into `.xpi`, read `browser_specific_settings.gecko.id`, back up `<profile>/extensions/<gecko-id>.xpi` once, and clear `<profile>/startupCache` when Zen is not running.
- **GTK3 / GTK4 & Flatpak:** Use `adw-gtk3-theme` + `org.gtk.Gtk3theme.adw-gtk3-dark`, write `@define-color` overrides in `~/.config/{gtk-3.0,gtk-4.0}/gtk.css`, set `settings.ini`, sync `kdeglobals` (`kwriteconfig6 --file kdeglobals --group General --key gtkTheme adw-gtk3-dark`), and grant Flatpak `:ro` access via `flatpak override --user`.

### 4. Script Architecture, Backups & Container-Host Safety
- **Paired Scripts:** Every `scripts/<area>-rice.sh` has a matching `scripts/<area>-revert.sh` wired into `scripts/apply-all.sh` and `scripts/revert-all.sh`.
- **One-Time `.rice.bak` Guard:** Never overwrite an existing `*.rice.bak` (`[[ -f "$f" && ! -f "$f.rice.bak" ]]`).
- **Root-Owned Workspace Safety:** Invoke workspace scripts with `bash "$script"` rather than requiring `+x`, stage `.xpi` builds in `mktemp -d`, and set `CARGO_TARGET_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/projects-rice-target"` (staging non-writable Rust project trees via `tar --exclude=target` into `$TMP_DIR`).
- **Preserve Source Assets on Revert:** `*-revert.sh` scripts must only clean host configs/packages and never delete tracked workspace source directories (e.g. `configs/hypr/**`).

## Output

Keep responses concise in the user's language, with clickable `file://` links to modified files and single-line copy-paste host commands pairing **Uygula** (Apply) and **Geri Al** (Revert). Report any checks skipped due to sandbox limits honestly.

## Constraints

- Keep existing DOM IDs, CSS class names, message types, and unit-tested text behavior intact when re-theming apps or extensions.
- Always back up existing user configs/binaries before overwriting and restore them cleanly in the paired `*-revert.sh`.
