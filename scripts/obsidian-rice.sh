#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSS_SRC="$SCRIPT_DIR/../configs/obsidian/tokyo-night.css"
DEFAULT_VAULT="$(cd "$SCRIPT_DIR/.." && pwd)/notes"
TARGET_VAULT="${1:-$DEFAULT_VAULT}"
APP_ID="md.obsidian.Obsidian"

echo "[1/3] Installing Obsidian (Flatpak) if missing..."
if command -v flatpak >/dev/null 2>&1; then
  if ! flatpak info "$APP_ID" >/dev/null 2>&1; then
    flatpak install -y flathub "$APP_ID"
  fi
fi

echo "[2/3] Granting scoped Flatpak filesystem access to $TARGET_VAULT..."
if command -v flatpak >/dev/null 2>&1 && [[ -d "$TARGET_VAULT" ]]; then
  flatpak override --user --filesystem="$TARGET_VAULT:rw" "$APP_ID"
fi

echo "[3/3] Installing Tokyo Night CSS snippet & minimal settings to Obsidian vaults..."
python3 - "$CSS_SRC" "$TARGET_VAULT" <<'EOF'
import json
import os
import shutil
import sys

css_src = sys.argv[1]
explicit_vault = sys.argv[2]


def ensure_writable(path: str) -> None:
    if os.path.exists(path):
        os.chmod(path, 0o644)


vaults = set()
if explicit_vault:
    ep = os.path.abspath(os.path.expanduser(explicit_vault))
    if os.path.isdir(ep):
        vaults.add(ep)

obs_json_paths = [
    os.path.expanduser("~/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"),
    os.path.expanduser("~/.config/obsidian/obsidian.json"),
]
for p in obs_json_paths:
    if os.path.isfile(p):
        try:
            data = json.load(open(p, "r", encoding="utf-8"))
            for v in data.get("vaults", {}).values():
                vp = v.get("path")
                if vp and os.path.isdir(vp):
                    vaults.add(vp)
        except Exception:
            pass

if not vaults:
    print("No existing Obsidian vaults found yet. Launch Obsidian once to create/open a vault, then re-run this script.")
    sys.exit(0)

for vp in sorted(vaults):
    obs_dir = os.path.join(vp, ".obsidian")
    snip_dir = os.path.join(obs_dir, "snippets")
    os.makedirs(snip_dir, exist_ok=True)
    dst_css = os.path.join(snip_dir, "tokyo-night.css")
    ensure_writable(dst_css)
    if os.path.isfile(dst_css) and not os.path.isfile(dst_css + ".rice.bak"):
        shutil.copy2(dst_css, dst_css + ".rice.bak")
    shutil.copy2(css_src, dst_css)

    app_cfg = os.path.join(obs_dir, "appearance.json")
    ensure_writable(app_cfg)
    if os.path.isfile(app_cfg) and not os.path.isfile(app_cfg + ".rice.bak"):
        shutil.copy2(app_cfg, app_cfg + ".rice.bak")
    cfg = {}
    if os.path.isfile(app_cfg):
        try:
            cfg = json.load(open(app_cfg, "r", encoding="utf-8"))
        except Exception:
            cfg = {}
    cfg["theme"] = "obsidian"
    cfg["frame"] = "native"
    cfg["accentColor"] = "#7aa2f7"
    cfg["baseFontSize"] = 16
    cfg["monospaceFont"] = "JetBrainsMono Nerd Font"
    cfg["showRibbon"] = False
    snippets = cfg.get("enabledCssSnippets", [])
    if "tokyo-night" not in snippets:
        snippets.append("tokyo-night")
    cfg["enabledCssSnippets"] = snippets
    with open(app_cfg, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")

    app_json = os.path.join(obs_dir, "app.json")
    ensure_writable(app_json)
    if os.path.isfile(app_json) and not os.path.isfile(app_json + ".rice.bak"):
        shutil.copy2(app_json, app_json + ".rice.bak")
    acfg = {}
    if os.path.isfile(app_json):
        try:
            acfg = json.load(open(app_json, "r", encoding="utf-8"))
        except Exception:
            acfg = {}
    acfg.pop("frame", None)
    acfg.pop("monospaceFont", None)
    acfg["showInlineTitle"] = False
    acfg["spellcheck"] = False
    acfg["propertiesInDocument"] = "source"
    acfg["useMarkdownLinks"] = True
    acfg["newFileLocation"] = "current"
    acfg["attachmentFolderPath"] = "./assets"
    acfg["alwaysUpdateLinks"] = True
    acfg["trashOption"] = "local"
    acfg["promptDelete"] = True
    acfg["foldHeading"] = True
    acfg["foldIndent"] = True
    acfg["autoPairBrackets"] = True
    acfg["autoPairMarkdown"] = True
    acfg["smartIndentList"] = True
    acfg["useTab"] = False
    acfg["tabSize"] = 2
    acfg["showUnsupportedFiles"] = False
    acfg["readableLineLength"] = True
    acfg["showLineNumber"] = True
    with open(app_json, "w", encoding="utf-8") as f:
        json.dump(acfg, f, indent=2)
        f.write("\n")

    hotkeys_json = os.path.join(obs_dir, "hotkeys.json")
    ensure_writable(hotkeys_json)
    if os.path.isfile(hotkeys_json) and not os.path.isfile(hotkeys_json + ".rice.bak"):
        shutil.copy2(hotkeys_json, hotkeys_json + ".rice.bak")
    hcfg = {}
    if os.path.isfile(hotkeys_json):
        try:
            hcfg = json.load(open(hotkeys_json, "r", encoding="utf-8"))
        except Exception:
            hcfg = {}
    hcfg["app:toggle-left-sidebar"] = [{"modifiers": ["Mod"], "key": "\\"}]
    hcfg["app:toggle-right-sidebar"] = [{"modifiers": ["Mod", "Shift"], "key": "\\"}]
    with open(hotkeys_json, "w", encoding="utf-8") as f:
        json.dump(hcfg, f, indent=2)
        f.write("\n")

    core_json = os.path.join(obs_dir, "core-plugins.json")
    ensure_writable(core_json)
    if os.path.isfile(core_json) and not os.path.isfile(core_json + ".rice.bak"):
        shutil.copy2(core_json, core_json + ".rice.bak")
    ccfg = {}
    if os.path.isfile(core_json):
        try:
            ccfg = json.load(open(core_json, "r", encoding="utf-8"))
        except Exception:
            ccfg = {}
    for pid in [
        "file-explorer",
        "global-search",
        "switcher",
        "graph",
        "backlink",
        "canvas",
        "properties",
        "page-preview",
        "command-palette",
        "editor-status",
        "bookmarks",
        "outline",
        "file-recovery",
        "bases",
    ]:
        ccfg[pid] = True
    for pid in [
        "outgoing-link",
        "tag-pane",
        "footnotes",
        "daily-notes",
        "templates",
        "note-composer",
        "slash-command",
        "zk-prefixer",
        "random-note",
        "word-count",
        "slides",
        "audio-recorder",
        "workspaces",
        "publish",
        "sync",
        "webviewer",
    ]:
        ccfg[pid] = False
    with open(core_json, "w", encoding="utf-8") as f:
        json.dump(ccfg, f, indent=2)
        f.write("\n")

    print(f"Applied Tokyo Night + minimal settings to vault: {vp}")
EOF

echo "Done. Restart Obsidian if open to load all updated JSON & CSS settings."
