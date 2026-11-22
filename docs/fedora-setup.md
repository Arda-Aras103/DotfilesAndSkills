# Fedora Linux + KDE Plasma (Wayland) Setup Guide

Baseline setup reference for Fedora Linux with KDE Plasma 6 (Wayland), unified Tokyo Night ricing, and a DevOps / Cloud / Systems development workflow.

## 1. System Update & Flatpak

```bash
sudo dnf upgrade --refresh -y
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

## 2. Core CLI & Developer Packages

```bash
sudo dnf install -y \
  git stow curl wget unzip 7zip ffmpeg \
  ripgrep fd-find bat fzf eza btop tmux jq htop pv \
  starship atuin yazi fastfetch kitty alacritty fuzzel \
  gcc make cmake python3 python3-pip
```

### Languages & Containers

- **Rust:** via `rustup` (`cargo`, `clippy`, `rustfmt`)
- **Go:** official tarball under `~/.local/go` (`PATH` configured in `.bashrc`)
- **Python:** `uv` / `uvx` for fast isolated environments
- **Docker:** installed with on-demand socket activation (`sudo systemctl enable --now docker.socket`, `sudo usermod -aG docker "$USER"`)

## 3. Desktop Applications (Flatpak)

```bash
flatpak install -y flathub \
  app.zen_browser.zen \
  com.discordapp.Discord \
  com.github.wwmm.easyeffects \
  com.obsproject.Studio \
  org.localsend.localsend_app \
  org.prismlauncher.PrismLauncher
```

## 4. Audio (EasyEffects Presets)

Presets live in `configs/easyeffects/`:

- `CMF-Buds-2-Clarity.json`
- `CMF-Buds-2-Cinema-Game.json`
- `Laptop-Speaker-Boost.json`
- `Clean-Mic-RNNoise.json`

Import them via EasyEffects or run `configs/easyeffects/setup-easyeffects-cmf.sh`.

## 5. System Hygiene

- **Btrfs Snapshots:** `snapper` root snapshots (manual / boot).
- **English XDG Directories:** `~/.config/user-dirs.conf` with `enabled=False`.
- **Baloo File Indexer:** disabled for lower background I/O (`balooctl6 disable`).
- **Maintenance Alias (in `.bashrc`):**
  ```bash
  alias upgrade="sudo dnf upgrade --refresh -y && flatpak update -y && sudo dnf autoremove -y"
  ```

## 6. Applying & Reverting the Tokyo Night Rice

```bash
./scripts/apply-all.sh
```

Every `*-rice.sh` script has a paired `*-revert.sh` script. To roll back everything:

```bash
./scripts/revert-all.sh
```
