---
name: fedora-sysadmin
description: Fedora Linux and KDE Plasma Wayland system diagnostics, network and rtw89 Wi-Fi fixes, systemd and D-Bus troubleshooting, GNU Stow symlink audits, and shell dotfile secret checks. Triggers include fedora ayar, wifi yavas, eduroam baglan, modprobe ayar, systemd servis, atuin fix, plasma ayar, d-bus kontrol, fedora sysadmin, dotfile kontrol, dotfile audit, stow kontrol, bashrc kontrol, broken symlink, dotfile doctor, secret check, parlaklik dusuyor, sanal klavye, oturum kapaniyor, sddm hata, powerdevil, espanso fix.
user-invocable: true
metadata:
  type: workflow
  version: "2.2"
---

# Fedora Sysadmin & Dotfile Doctor

System, network, and KDE Plasma diagnostics for Fedora Linux alongside shell dotfile, GNU Stow symlink, and secret-leak audits.

## When & Modes

- **Mode 1 — Fedora / KDE System & Network Diagnostics:** `eduroam` 802.1X auth, `rtw89` Wi-Fi power-save/ASPM latency, `systemd-resolved` DNS-over-TLS, `systemd` user/system services (including Wayland service races like `espanso`), `atuin` locks, D-Bus, Plasma Wayland/SDDM session logouts, PowerDevil post-lock brightness drops, or virtual-keyboard suppression.
- **Mode 2 — Dotfile, Shell & Secret Audit:** Auditing `.bashrc`, `.profile`, `.gitconfig`, GNU Stow symlinks, `$PATH` duplicates, alias collisions, or secret leaks.

## Workflow

### Mode 1 — System & Network Diagnostics
1. Pinpoint the failing layer:
   - **Wi-Fi / Hardware (`rtw89` / `eduroam`):** NetworkManager 802.1X PEAP/MSCHAPv2 config, `/etc/modprobe.d/rtw89.conf` (`disable_ps_mode`, ASPM flags).
   - **DNS / Routing:** `resolvectl status`, `systemd-resolved` DNSOverTLS, `ip route` / `ip neigh`.
   - **Shell / Services / D-Bus:** `atuin` `PROMPT_COMMAND` & SQLite locks, `systemctl --user`, `busctl` / `journalctl`.
   - **Session / Display Manager & Wayland Ordering:** 90s Plasma Wayland/NVIDIA logouts (`sddm-wayland-plasma` `sddm-helper exited with 2` -> prefer Fedora native `plasmalogin.service` or `sddm-x11`; diagnose via `scripts/diagnose-session-crash.sh`, `journalctl --user -b 0`, `loginctl list-sessions`); fix Wayland user-service races (e.g. `espanso.service` `NoCompositor`) with a systemd drop-in `After=graphical-session.target plasma-kwin_wayland.service` + `PartOf=graphical-session.target`.
   - **PowerDevil / Backlight & Virtual Keyboard:** Post-lock brightness drops -> check `/sys/class/backlight/*` (`brightness` vs `actual_brightness`), set `DimDisplayWhenIdle=false` in `powerdevilrc`, and add `Environment=POWERDEVIL_NO_DDCUTIL=1` drop-in when `/dev/i2c-*` `EACCES` breaks DDC/CI; toggle system-wide virtual keyboard via `scripts/vkbd-off.sh` / `scripts/vkbd-on.sh` (`kwinrc` + greeter `InputMethod=`).
2. Deliver single-line, copy-paste-ready diagnostic and fix commands (use safe heredocs `cat << 'EOF' | sudo tee ...` for root files), always paired with an exact rollback/cleanup command.

### Mode 2 — Dotfile & Secret Audit
1. Run the bundled read-only diagnostic script from `/workspace`:
   ```bash
   ./.agents/skills/fedora-sysadmin/scripts/audit_dotfiles.sh <target_dir>
   ```
   Checks: (1) Secret/token patterns (outputs `file:line` only, values masked), (2) broken symlinks (`find -L ~ -maxdepth 3 -type l`), (3) `bash -n` shell syntax, (4) duplicate aliases in `.bashrc`.
2. Verify `$PATH` edits avoid duplicates/unquoted expansions and `/workspace/scripts/*.sh` scripts include `set -euo pipefail` guards. Report findings by severity (`Kritik / Uyarı / İyileştirme`) with minimal diffs.

## Output

Follow `/workspace/.agents/rules/AGENTS.md`: concise root-cause summary + copy-paste single-line **Teşhis / Düzeltme** commands + **Geri Alma (Rollback)** commands. Avoid bloated multi-page templates.

## Constraints

- Never recommend `chmod 777` or disabling SELinux/firewalld permanently without explicit warning.
- Never print raw detected private keys, tokens, or passwords in chat or script output; always mask secret values.
- Read-only diagnostics by default; never overwrite user dotfiles or `/etc/` files without rollback steps.
