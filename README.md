# DotfilesAndSkills

Personal **Fedora Linux + KDE Plasma 6 (Wayland)** dotfiles, unified **Tokyo Night** desktop rice (with paired revert scripts), **19 modular AI agent skills**, and **Antigravity lifecycle hooks**.

## Repository Structure

```text
.
├── .bashrc                 # Interactive Bash config (Starship, Atuin, eza, bat, fzf, yazi, Fedora aliases)
├── .gitconfig              # Git defaults and global ignore wiring
├── .gitignore_global       # Global gitignore patterns
├── .profile                # Login shell entry point
├── configs/                # Application, terminal, KDE, Hypr/KWin, SDDM, Plymouth, EasyEffects & Zen configs
├── docs/
│   ├── fedora-setup.md     # Fedora + KDE Plasma + Flatpak + DevOps bootstrap guide
│   └── ssh.md              # GitHub SSH key setup guide
├── hooks/                  # Antigravity PreToolUse / PostToolUse / PreInvocation / Stop / SessionStart hooks
├── scripts/                # Paired *-rice.sh / *-revert.sh scripts + apply-all.sh / revert-all.sh + doctors
└── skills/                 # 19 modular AI agent skills (SKILL.md + helper scripts & references)
```

## Quick Start

### 1. Shell & Git Dotfiles

```bash
git clone git@github.com:Arda-Aras103/DotfilesAndSkills.git ~/DotfilesAndSkills
cd ~/DotfilesAndSkills
cp .bashrc ~/.bashrc
cp .profile ~/.profile
cp .gitconfig ~/.gitconfig
cp .gitignore_global ~/.gitignore_global
source ~/.bashrc
```

*(Alternatively, organize into GNU Stow packages if you prefer symlink management.)*

### 2. KDE Plasma 6 Tokyo Night Rice

Apply the full desktop, panel, GTK, terminal, CLI/TUI, Zen Browser, Zed, and Obsidian theme suite:

```bash
./scripts/apply-all.sh
```

Revert all rice changes cleanly:

```bash
./scripts/revert-all.sh
```

> **Note (SDDM `cyber-wireframe`):** Personal login photos are excluded from this public repository. `configs/sddm/cyber-wireframe/` falls back to `default-frame.svg`, or you can place your own `login-photo.jpg` inside `configs/sddm/cyber-wireframe/` before running `scripts/sddm-cyber-rice.sh`.

### 3. AI Agent Skills (`skills/`)

Copy or symlink `skills/` into your workspace's `.agents/skills/` (or `~/.claude/skills/`):

| Skill | Purpose |
| :--- | :--- |
| `academic-notes` | Structured Markdown study notes & 5-level TextFold digests for arXiv papers and lectures |
| `application-tracker` | Internship/job pipeline tracking, CV/ATS keyword matching, and portfolio coaching |
| `attendance-tracker` | University course attendance & absence tracking |
| `channel-radar` | Weekly YouTube channel video radar (last 168h, skips Shorts/members-only) |
| `fedora-sysadmin` | Fedora & KDE Wayland diagnostics, Wi-Fi/systemd/D-Bus fixes, Stow & dotfile audits |
| `google-calendar` | Generates copy-paste Google Calendar prompts from deadlines and trackers |
| `handoff` | Compacts session state, verified facts, blockers, and next commands into a handoff note |
| `improve-codebase-architecture` | Read-only architectural survey for shallow modules and deep-module refactor proposals |
| `inbox-triage` | Triages dropped links, repos, videos, and screenshots against user preferences |
| `kde-tokyo-rice` | KDE Plasma 6 Wayland Hyprland-style ricing & Tokyo Night unification |
| `media-game-guide` | Runtime cards, continue/drop decisions, QoL mod loadouts, and settings tables |
| `media-web-archiver` | YouTube (`yt-dlp`), batch direct downloads (`wget`), and offline single-file HTML archiving |
| `opportunity-scan` | Weekly/monthly scan of internships, hackathons, cloud vouchers, and term windows |
| `opportunity-verdict` | Listing/scholarship verdicts (`apply`/`shaky`/`skip`) and 100-point hackathon Fit Scores |
| `playwright-cli` | Token-efficient interactive web testing and SPA debugging via `playwright-cli` |
| `repo-inspector` | Codebase onboarding and pre-release readiness audits (Rust, Go, Python, WebExtensions) |
| `reverse-inspect` | Evidence-based binary/bundle inspection (ELF, PE, asar, JS bundles, HAR, Ghidra/REA) |
| `skill-workshop` | Designs, evaluates, creates, and patches workspace `SKILL.md` files |
| `vocabulary` | Formats English vocabulary entries into compact Markdown dictionary tables with validation |

### 4. Agent Lifecycle Hooks (`hooks/`)

Includes `hooks/hooks.json` and 6 Python hook scripts:

- `pretool_safety_guard.py` — hard-blocks catastrophic `rm`/destructive commands and private credential reads; forces confirmation on risky operations.
- `posttool_validator.py` — validates edits/commands after execution.
- `preinvocation_feedback.py` — pre-invocation guard/feedback hook.
- `stop_verification_gate.py` — stop-time verification check.
- `session_start_context.py` — injects session-start context and deadline reminders.
- `hook_common.py` — shared JSON I/O and tool-matching helpers.

To wire them into an Antigravity workspace, place `hooks.json` in `.agents/hooks.json` and point its command paths to where you place the Python hook scripts.

## Intentionally Excluded

Never tracked in this repository:

- `~/.ssh/`, `~/.aws/`, `~/.gnupg/`, `~/.docker/`, `~/.gemini/`
- Shell history (`~/.bash_history`, `~/.local/share/atuin/`)
- API keys, `.env` / `keys.env`, `gh/hosts.yml`, or any token files
- Personal photos (`login-photo.jpg`), CVs, private reports, or personal opportunity filter lists
- Browser profiles, Steam libraries, and cache/bytecode (`__pycache__/`)

## Security Check Before Pushing

```bash
git ls-files | xargs grep -lEi 'sk-[a-z0-9]{20}|ghp_[a-z0-9]{20}|AIza[0-9A-Za-z_-]{30}|AKIA[0-9A-Z]{16}|api[_-]?key\s*[:=]' 2>/dev/null
```
