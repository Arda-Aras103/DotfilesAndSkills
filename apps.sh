# Debian Main Machine

The main machine runs Debian 13 (trixie), a full install and not WSL. The desktop is KDE Plasma, the architecture is amd64, and non-free firmware was enabled during install.

Document date: 2026-10-01. Versions were verified on that date. Recheck before updating anything.

Installation order: `apt` first, then Flatpak if no apt package exists, then Wine or Bottles if neither works. Third-party install scripts are not used.

## Contents

- Why Debian
- First-time setup
- Base packages
- Development tools
- System helpers
- Applications
- Steam
- Hardware and helper tools
- Terminal tools
- Configuration directories
- Post-install checklist
- Version notes

## Why Debian

Debian 13 is stable for school, Go, Docker, and AWS work. It does not upgrade itself during the school year.

The main benefit is that the machine matches the server environment. Go, Docker, AWS, and the Linux servers at the internship behave the same way at home. Path, permission, memory, and systemd differences from WSL disappear.

- Docker and CLI tools run natively. `lazydocker`, `dive`, `gh`, and `atuin` do not depend on a second virtual machine, and RAM is not split with Windows.
- Software is installed and removed in one place. `apt` and Flatpak show what is installed.
- The desktop is configured locally. KDE workspaces, shortcuts, and `keyd` belong to the machine. There is no account requirement and no built-in ads or background assistant.

The cost is some applications. WhatsApp and YouTube Music stay in the browser. Discord screen sharing on Wayland occasionally misbehaves. Steam games with anti-cheat may not launch. AutoHotkey scripts are rewritten for `keyd` one by one. Printer, Wi-Fi, and game setup take the first week.

If the laptop is a 2026 model and Wi-Fi or the display fails during installation, check the kernel and firmware separately.

## First-time setup

```bash
sudo apt install flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

```bash
sudo apt install mpv qbittorrent keyd 7zip ffmpeg
flatpak install flathub \
  com.discordapp.Discord \
  org.localsend.localsend_app \
  com.obsproject.Studio \
  org.prismlauncher.PrismLauncher \
  app.zen_browser.zen
```

## Base packages

Installed from the Debian 13 main repository. Check availability with `apt show <package>` before installing.

```bash
sudo apt install build-essential unzip wget htop tmux jq ripgrep fd-find bat fzf
```

- `fd-find` installs `fdfind` and `bat` installs `batcat`. Alias them to the usual names in `~/.bashrc`.
- `build-essential` provides `gcc`, `make`, and related tools for building from source.

## Development tools

### Go

Use the official tarball from https://go.dev/dl/, extracted under `~/.local`. Do not use a third-party apt repository.

```bash
export PATH="$HOME/.local/go/bin:$HOME/go/bin:$PATH"
```

Take the version number from the download page at install time. Check with `go version`.

### Node.js and npm

Use the official tarball from https://nodejs.org/en/download, extracted under `~/.local`. npm ships with Node, so the Debian `npm` package is not used.

Check with `node --version` and `npm --version`.

### Docker

Debian's `docker.io` package from the trixie archive is used. Docker's upstream repository is not added. Archive versions can lag behind upstream.

```bash
sudo apt install docker.io docker-compose
sudo usermod -aG docker "$USER"
```

Log out and back in after `usermod`, or the group change will not apply.

## System helpers

```bash
sudo apt install btop timeshift ufw
sudo ufw enable
```

- `btop`: process and resource monitor, an alternative to `htop`.
- `timeshift`: system snapshots for rollback. Set the snapshot location before the first run.
- `ufw`: firewall front end. Confirm SSH rules before enabling it on a remote machine.

Power profiles are covered in the GHelper section.

## Applications

| Windows | Linux | Installation |
|---|---|---|
| mpv | mpv | `sudo apt install mpv` |
| qBittorrent | qBittorrent | `sudo apt install qbittorrent` |
| AutoHotkey | keyd and KDE shortcuts | `sudo apt install keyd` |
| Flow Launcher | KRunner | Included with Plasma, `Alt+Space` |
| Discord | Discord | `flatpak install flathub com.discordapp.Discord` |
| LocalSend | LocalSend | `flatpak install flathub org.localsend.localsend_app` |
| OBS | OBS Studio | `flatpak install flathub com.obsproject.Studio` |
| Prism Launcher | Prism Launcher | `flatpak install flathub org.prismlauncher.PrismLauncher` |
| Zen | Zen | `flatpak install flathub app.zen_browser.zen` |
| Steam | Steam | Valve `steam.deb` |
| WhatsApp | WhatsApp Web | `web.whatsapp.com` in Zen |
| YT Music | YouTube Music | `music.youtube.com` in Zen |
| 7-Zip | 7-Zip | `sudo apt install 7zip` |
| ffmpeg | ffmpeg | `sudo apt install ffmpeg` |
| yt-dlp | yt-dlp | `trixie-backports`, 2026.08.19 |
| Google Chrome | Google Chrome | Official `.deb` |
| SecureW2 EAP Suite 1.1.1 | Not installed | KDE Wi-Fi, Ege eduroam |

### AutoHotkey

`keyd` handles system-wide remapping, layers, and macros on Wayland. Application launch shortcuts are set in KDE Settings, under Shortcuts. The AHK script is not carried over; each script is rewritten separately.

### Flow Launcher

KRunner covers apps, windows, accounts, and web search. Plugins are added from Settings, under KRunner.

### OBS

The Debian `obs-studio` package is 30.2.3. For a current version and browser source support, use the Flatpak.

### Prism Launcher

The Flatpak manages Java and versions itself. The apt package exists only in `trixie-backports`, under `contrib`.

### Zed

The official installer places files under `~/.local`. No third-party apt repository is added.

### Discord

Flatpak. If screen sharing freezes on Wayland, test it again separately.

### WhatsApp and YouTube Music

Neither has an official Linux desktop app. In Zen, install each site as an app from the menu.

Unofficial options exist for a separate window or media keys: a `.deb` for YouTube Music at https://github.com/th-ch/youtube-music, and ZapZap (`com.rtosta.zapzap`) for a WhatsApp tray icon.

### 7-Zip

`sudo apt install 7zip`, command `7z`, version 25.01. Ark opens archives in KDE. For RAR support, install `7zip-rar` separately.

### Google Chrome

```bash
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome-stable_current_amd64.deb
```

The installer adds Google's repository. Zen stays the daily browser. Chrome is for sites that require it.

### github.com

Use the site in Zen with the Refined GitHub extension. Use `gitui` for local commits, `gh` for PRs and issues (`gh auth login`, `gh browse`), and `gh-dash` for a dashboard.

### SecureW2 EAP Suite 1.1.1

A Windows-only 802.1X client with no Linux package. It does not run under Wine. The KDE Wi-Fi settings do the same job through `wpa_supplicant`.

Settings published by Ege University for Windows 8: https://eduroam.ege.edu.tr/tr-13263/windows_8.html

- Network: `eduroam`
- Security: WPA2-Enterprise, AES
- EAP method: TTLS
- Anonymous identity: `anonymous`
- Inner authentication: PAP
- Student user: `your_student_number@ogrenci.ege.edu.tr`
- Password: your `kimlik.ege.edu.tr` password

## Steam

Use Valve's own `.deb`. Do not install 32-bit packages by hand. On first launch, Steam asks for the libraries it needs.

1. Download https://cdn.fastly.steamstatic.com/client/installer/steam.deb.
2. In the download folder:

```bash
sudo apt install ./steam.deb
```

3. Open Steam from the menu. Confirm the password prompt if it appears. Steam installs the 32-bit libraries and then downloads the client.

The Flathub Steam (`com.valvesoftware.Steam`) is a community package, not Valve's. Games stay inside the home folder. Installing to another disk requires permission on that folder.

The Debian archive path also works, with `contrib` enabled:

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install steam-installer steam-devices mesa-vulkan-drivers libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386
```

## Hardware and helper tools

### QuickLook

On KDE, Dolphin is the built-in option. Select a file and press F11 for the info panel. For thumbnails:

```bash
sudo apt install ffmpegthumbs kdegraphics-thumbnailers
```

For a spacebar preview window, use Flathub `org.previewqt.PreviewQt`. It runs in the tray and is bound to Ctrl+Space in Dolphin. It previews images, audio, video, PDFs, office files, archives, and text.

```bash
flatpak install flathub org.previewqt.PreviewQt
```

### GHelper

GHelper has no Linux version. On an ASUS ROG, TUF, or Zephyrus, the equivalents are `asusctl`, `supergfxctl`, and `rog-control-center` from asus-linux.org. These are not in the Debian 13 repository, and the project does not support Debian, so they are not covered here.

On other hardware, use the Plasma power settings and `power-profiles-daemon` for quiet, balanced, and performance profiles where the kernel supports them.

### NVIDIA

Linux has no NVIDIA App or GeForce Experience. Debian 13 ships the 550.163 driver series, which covers Maxwell through Ada and Hopper. RTX 50 (Blackwell) cards are not covered by this series, so choose a different source for those.

Source lines must include `main contrib non-free non-free-firmware`. Reference: https://wiki.debian.org/NvidiaGraphicsDrivers

```bash
sudo apt install linux-headers-$(uname -r)
sudo apt install nvidia-kernel-dkms nvidia-driver
```

The open kernel module (`nvidia-open-kernel-dkms`) is for Turing and newer. The Debian wiki reports that the 550.163.01-2 open driver does not build on kernel 6.12.100 (bug 1143204), so the closed package is used here.

Reboot, then check:

```bash
nvidia-smi
```

For monitoring:

```bash
sudo apt install nvidia-settings nvtop
```

`nvidia-settings` cannot change some settings on a Wayland session. If the session falls back to X11, the steps are on the same wiki page. There is no `.run` installer.

## Terminal tools

The tools are fixed to the versions listed in Version notes. `gh` and `dive` install as `.deb` packages into `/usr/bin`. The rest go into `~/.local/bin`. The install script's own apt step installs only `curl`, `ca-certificates`, `git`, `tar`, and `gzip`. Every download is verified with SHA-256.

```bash
bash install-tuis.sh
```

## Configuration directories

The following directories were copied from the WSL setup into `~/.config` on the Debian machine:

| Directory | Tool | Notes |
|---|---|---|
| `atuin` | Atuin shell history | Shell hook is in `~/.bashrc`. The sync key is stored under `~/.local/share/atuin`, not here. |
| `btop` | btop | Theme and settings. |
| `gh` | GitHub CLI | Can contain auth data. Prefer `gh auth login` over copying `hosts.yml`. |
| `gh-dash` | gh-dash | PR and issue dashboard layout. |
| `gitui` | gitui | Key bindings and theme. |
| `go` | Go | Usually empty or minimal. The real paths are set in `~/.bashrc`. |
| `htop` | htop | Process list layout. |
| `lazydocker` | lazydocker | Docker TUI settings. |
| `lstk` | lstk | Purpose not recorded in this document. Check the contents before copying. |
| `zed` | Zed | Settings, keymap, and extensions list. |

Copy with ownership and permissions intact:

```bash
mkdir -p ~/.config
cp -a /mnt/c/Users/<windows-user>/.config/<dir> ~/.config/   # adjust the source path
```

Some of these directories hold private data. Keep them at their current permissions (`700` for `atuin` and `htop`, `751` for `gh`). Do not commit them to a public repository.

Atuin: history stays local unless sync is set up. Import old history after copying the shell hook:

```bash
atuin import auto
```

Check each directory after copying. Settings tied to Windows paths, such as `/mnt/c` or `powershell.exe` calls, must be changed by hand.

## Post-install checklist

- [ ] `source ~/.bashrc`
- [ ] `gh auth login` (once)
- [ ] `atuin import auto` (optional, old history)
- [ ] Copy `~/.config` directories from the table above and check paths
- [ ] `nvidia-smi` after reboot (NVIDIA cards only)
- [ ] Test the eduroam connection from the KDE Wi-Fi screen
- [ ] Set application shortcuts in KDE Settings, under Shortcuts

## Version notes

Written on 2026-10-01. Versions listed here (yt-dlp 2026.08.19, obs-studio 30.2.3, gh 2.101.0, and others) were verified on that date. Check the relevant section again before updating any tool.
