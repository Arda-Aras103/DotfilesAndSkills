#!/usr/bin/env bash
# Syncs /workspace dotfiles, configs, skills, hooks, and scripts into DotfilesAndSkills,
# runs secret/JSON hygiene checks, and optionally commits & pushes.
#
# Usage:
#   ./scripts/sync-dotfiles.sh                     # Sync into /tmp/DotfilesAndSkills (inspect only)
#   ./scripts/sync-dotfiles.sh /path/to/repo       # Sync into an existing or new repo path
#   ./scripts/sync-dotfiles.sh --push              # Sync, commit, and push to origin/main
set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/Arda-Aras103/DotfilesAndSkills.git}"
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DO_PUSH=0
TARGET_DIR="/tmp/DotfilesAndSkills"

for arg in "$@"; do
  case "$arg" in
    --push) DO_PUSH=1 ;;
    -h|--help)
      sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) TARGET_DIR="$arg" ;;
  esac
done

if [[ ! -d "$TARGET_DIR/.git" ]]; then
  rm -rf "$TARGET_DIR"
  git clone "$REPO_URL" "$TARGET_DIR"
else
  git -C "$TARGET_DIR" pull --ff-only
fi

python3 - "$WORKSPACE_DIR" "$TARGET_DIR" <<'PY'
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ws = Path(sys.argv[1])
repo = Path(sys.argv[2])

# 1. .bashrc
shutil.copy2(ws / "configs" / "bashrc", repo / ".bashrc")

# 2. configs/ (excluding stale/personal/cache files)
cfg_src = ws / "configs"
cfg_dst = repo / "configs"
if cfg_dst.exists():
    shutil.rmtree(cfg_dst)
cfg_dst.mkdir()

for item in sorted(cfg_src.iterdir()):
    if item.name in {"bash", "bashrc"}:
        continue
    dst = cfg_dst / item.name
    if item.is_dir():
        shutil.copytree(
            item,
            dst,
            ignore=shutil.ignore_patterns(
                "__pycache__", "*.pyc", "login-photo.jpg", "hidden-opportunities.txt"
            ),
        )
    else:
        shutil.copy2(item, dst)

(cfg_dst / "zen" / "hidden-opportunities.example.txt").write_text(
    "! Title: Zen Hidden Opportunities (Example)\n"
    "! Description: Cosmetic uBlock Origin filter list for hiding reviewed/skipped listings.\n"
    "! Expires: 1 hours\n"
    "!\n"
    "! Example rule:\n"
    '! example.com##a[href*="/jobs/example-role" i]:upward(article, li, [class*="card"])\n'
)

# 3. skills/
skills_dst = repo / "skills"
if skills_dst.exists():
    shutil.rmtree(skills_dst)
shutil.copytree(
    ws / ".agents" / "skills",
    skills_dst,
    ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
)

# 4. hooks/
hooks_dst = repo / "hooks"
if hooks_dst.exists():
    shutil.rmtree(hooks_dst)
hooks_dst.mkdir()

hooks_json = (ws / ".agents" / "hooks.json").read_text()
(hooks_dst / "hooks.json").write_text(
    hooks_json.replace("python3 ../scripts/", "python3 ./")
)

hook_files = {
    "hook_common.py",
    "pretool_safety_guard.py",
    "posttool_validator.py",
    "preinvocation_feedback.py",
    "stop_verification_gate.py",
    "session_start_context.py",
}
for f in sorted(hook_files):
    shutil.copy2(ws / "scripts" / f, hooks_dst / f)

# 5. scripts/ (curated, excluding personal/test/hook scripts)
scripts_dst = repo / "scripts"
if scripts_dst.exists():
    shutil.rmtree(scripts_dst)
scripts_dst.mkdir()

exclude_scripts = hook_files | {
    "build_motivation_letter.py",
    "update_cv.py",
    "hide-opportunity.py",
    "autoclicker.sh",
    "gemini_decision.py",
    "gemini-decision-setup.sh",
}
for p in sorted((ws / "scripts").iterdir()):
    if not p.is_file():
        continue
    if p.name in exclude_scripts or p.name.startswith("test_"):
        continue
    shutil.copy2(p, scripts_dst / p.name)

# 6. Hygiene & validation checks
subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)
tracked = subprocess.check_output(
    ["git", "-C", str(repo), "ls-files"], text=True
).splitlines()

secret_pat = re.compile(
    r"(?i)(sk-[a-z0-9]{20,}|ghp_[a-z0-9]{20,}|gho_[a-z0-9]{20,}|"
    r"AIza[0-9A-Za-z_-]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9a-zA-Z-]{10,}|"
    r"BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE KEY)"
)
secret_hits = []
json_errors = []
forbidden = ("login-photo.jpg", "hidden-opportunities.txt", "keys.env", "__pycache__", ".pyc")
forbidden_hits = [r for r in tracked if any(f in r for f in forbidden)]

for rel in tracked:
    p = repo / rel
    if p.suffix in {".svg", ".png", ".jpg"}:
        continue
    text = p.read_text(errors="ignore")
    if secret_pat.search(text):
        secret_hits.append(rel)
    if rel.endswith(".json"):
        try:
            json.loads(text)
        except Exception as exc:
            json_errors.append(f"{rel}: {exc}")

if secret_hits or json_errors or forbidden_hits:
    print("[ERROR] Hygiene check failed!", file=sys.stderr)
    if secret_hits:
        print("  Secret hits:", secret_hits, file=sys.stderr)
    if json_errors:
        print("  JSON errors:", json_errors, file=sys.stderr)
    if forbidden_hits:
        print("  Forbidden files:", forbidden_hits, file=sys.stderr)
    sys.exit(1)

print(f"[OK] Synced {len(tracked)} files cleanly (0 secrets, 0 JSON errors).")
PY

echo ""
git -C "$TARGET_DIR" status --short

if git -C "$TARGET_DIR" diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

if [[ "$DO_PUSH" -eq 1 ]]; then
  git -C "$TARGET_DIR" commit -m "Sync dotfiles, configs, skills, hooks, and scripts ($(date +%Y-%m-%d))"
  GIT_ASKPASS= git -C "$TARGET_DIR" push origin main
  echo "Pushed cleanly to origin/main."
else
  echo ""
  echo "Review above, then commit & push with:"
  echo "  git -C \"$TARGET_DIR\" commit -m \"Sync dotfiles ($(date +%Y-%m-%d))\" && GIT_ASKPASS= git -C \"$TARGET_DIR\" push origin main"
fi
