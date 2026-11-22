#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_DIR="$WORKSPACE_DIR/projects"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export CARGO_TARGET_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/projects-rice-target"
mkdir -p "$CARGO_TARGET_DIR"

ZEN_EXTS=(
  "zen-cleanlink"
  "zen-github-xray"
  "zen-recon-hub"
  "zen-virustotal-scanner"
  "zen-linux-bridge"
)

ZEN_PROFILE_ROOTS=(
  "$HOME/.zen"
  "$HOME/.var/app/app.zen_browser.zen/.zen"
  "$HOME/.var/app/io.github.zen_browser.zen/.zen"
)

prepare_rust_dir() {
  local name="$1"
  local src_dir="$2"
  if [[ -w "$src_dir" ]] && { [[ ! -e "$src_dir/Cargo.lock" ]] || [[ -w "$src_dir/Cargo.lock" ]]; }; then
    printf '%s\n' "$src_dir"
    return
  fi
  local stage_dir="$TMP_DIR/$name"
  mkdir -p "$stage_dir"
  tar --exclude=target -cf - -C "$src_dir" . | tar -xf - -C "$stage_dir"
  printf '%s\n' "$stage_dir"
}

zen_running=false
if pgrep -x zen >/dev/null 2>&1 || pgrep -f 'zen-bin' >/dev/null 2>&1; then
  zen_running=true
fi

echo "==> [1/3] Packaging Zen Browser extensions with Tokyo Night theme..."
updated_profiles=0

for ext in "${ZEN_EXTS[@]}"; do
  ext_dir="$PROJECTS_DIR/$ext"
  if [[ ! -f "$ext_dir/manifest.json" ]]; then
    echo "  [SKIPPED] $ext (missing manifest.json)"
    continue
  fi

  built_xpi="$TMP_DIR/$ext.xpi"
  built_zip="$TMP_DIR/$ext.zip"

  python3 - "$ext_dir" "$built_zip" "$built_xpi" <<'PY'
import os
import shutil
import sys
import zipfile

ext_dir, out_zip, out_xpi = sys.argv[1], sys.argv[2], sys.argv[3]
files = [
    "manifest.json",
    "background.js",
    "content.js",
    "content.css",
    "popup.html",
    "popup.css",
    "popup.js",
    "icons/icon.svg",
]
optional_files = ["xray_core.js"]

with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for rel_path in files:
        full_path = os.path.join(ext_dir, rel_path)
        if not os.path.isfile(full_path):
            raise FileNotFoundError(f"Missing required extension file: {full_path}")
        zf.write(full_path, arcname=rel_path)
    for rel_path in optional_files:
        full_path = os.path.join(ext_dir, rel_path)
        if os.path.isfile(full_path):
            zf.write(full_path, arcname=rel_path)

shutil.copyfile(out_zip, out_xpi)
PY

  chmod 644 "$built_zip" "$built_xpi"

  if [[ -w "$ext_dir" ]]; then
    if [[ ! -e "$ext_dir/$ext.zip" || -w "$ext_dir/$ext.zip" ]]; then
      cp -f "$built_zip" "$ext_dir/$ext.zip"
    fi
    if [[ ! -e "$ext_dir/$ext.xpi" || -w "$ext_dir/$ext.xpi" ]]; then
      cp -f "$built_xpi" "$ext_dir/$ext.xpi"
    fi
  fi

  gecko_id="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print(d.get("browser_specific_settings",{}).get("gecko",{}).get("id",""))' "$ext_dir/manifest.json")"
  if [[ -z "$gecko_id" ]]; then
    echo "  [WARN] Could not read gecko ID for $ext; skipping profile update."
    continue
  fi

  for root in "${ZEN_PROFILE_ROOTS[@]}"; do
    [[ -d "$root" ]] || continue
    for prof in "$root"/*; do
      [[ -d "$prof/extensions" ]] || continue
      target_xpi="$prof/extensions/$gecko_id.xpi"
      if [[ -f "$target_xpi" ]]; then
        if [[ ! -e "$target_xpi.rice.bak" ]]; then
          cp -a "$target_xpi" "$target_xpi.rice.bak"
        fi
        install -m 644 "$built_xpi" "$target_xpi"
        if [[ "$zen_running" == false && -d "$prof/startupCache" ]]; then
          rm -rf "$prof/startupCache"
        fi
        echo "  [UPDATED] $target_xpi"
        updated_profiles=$((updated_profiles + 1))
      fi
    done
  done
done

echo "==> [2/3] Building KQuickLook and KZapret with Tokyo Night theme..."
if ! command -v cargo >/dev/null 2>&1; then
  echo "ERROR: 'cargo' not found. Install with: sudo dnf install -y cargo rust"
  exit 1
fi

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

run_installer_with_target() {
  local name="$1"
  local build_dir="$2"
  local inst_dir="$build_dir"
  if [[ -e "$inst_dir/target" && ! -L "$inst_dir/target" ]]; then
    inst_dir="$TMP_DIR/$name-inst"
    mkdir -p "$inst_dir"
    tar --exclude=target -cf - -C "$build_dir" . | tar -xf - -C "$inst_dir"
  fi
  ln -sfn "$CARGO_TARGET_DIR" "$inst_dir/target"
  bash "$inst_dir/install.sh"
}

# KQuickLook
kql_dir="$PROJECTS_DIR/kquicklook"
if [[ -d "$kql_dir" ]]; then
  echo "  -> KQuickLook test + release build..."
  kql_build_dir="$(prepare_rust_dir kquicklook "$kql_dir")"
  (cd "$kql_build_dir" && cargo test --quiet && cargo build --release)
  if [[ -x "$BIN_DIR/kquicklook" ]]; then
    if [[ ! -e "$BIN_DIR/kquicklook.rice.bak" ]]; then
      cp -a "$BIN_DIR/kquicklook" "$BIN_DIR/kquicklook.rice.bak"
    fi
    install -m 755 "$CARGO_TARGET_DIR/release/kquicklook" "$BIN_DIR/kquicklook"
    if command -v systemctl >/dev/null 2>&1; then
      systemctl --user try-restart kquicklook-dolphin.service >/dev/null 2>&1 || true
    fi
    echo "  [UPDATED] $BIN_DIR/kquicklook"
  else
    run_installer_with_target kquicklook "$kql_build_dir"
  fi
fi

# KZapret
kz_dir="$PROJECTS_DIR/kzapret"
if [[ -d "$kz_dir" ]]; then
  echo "  -> KZapret release build..."
  kz_build_dir="$(prepare_rust_dir kzapret "$kz_dir")"
  (cd "$kz_build_dir" && cargo build --release)
  if [[ -x /usr/local/bin/kzapret-ctl && -f /etc/polkit-1/rules.d/50-kzapret.rules ]]; then
    if [[ -x "$BIN_DIR/kzapret" && ! -e "$BIN_DIR/kzapret.rice.bak" ]]; then
      cp -a "$BIN_DIR/kzapret" "$BIN_DIR/kzapret.rice.bak"
    fi
    install -m 755 "$CARGO_TARGET_DIR/release/kzapret" "$BIN_DIR/kzapret"
    echo "  [UPDATED] $BIN_DIR/kzapret"
  else
    echo "  -> KZapret system helper not installed yet, running install.sh..."
    run_installer_with_target kzapret "$kz_build_dir"
  fi
fi

echo "==> [3/3] Done ($updated_profiles profile extension(s) updated)."
if [[ "$zen_running" == true ]]; then
  echo "NOTE: Zen Browser is currently running. Restart Zen Browser to load updated extension themes."
fi
echo "NOTE: If using userscripts, update via Tampermonkey/Violentmonkey:"
echo "     $PROJECTS_DIR/zen-open-integrations/userscripts/zen-github-arxiv-powerpack.user.js"
