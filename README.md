# DotfilesAndSkills

Personal Debian 13 dotfiles, shell configuration, and Claude skill files.

## Contents

- `.bashrc`: interactive shell configuration (PATH, aliases, prompt, helper functions)
- `.profile`: login shell entry point, loads `.bashrc`
- `.bash_logout`: clears the console on exit of a login shell
- `.gitignore_global`: global ignore rules for all repositories
- `.gitconfig`: Git identity and global excludes file
- `apps.md`: Debian setup guide (packages, Flatpak apps, Steam, NVIDIA, eduroam)
- `install-tuis.sh`: installs terminal tools into `~/.local/bin`
- `.config/`: selected application configuration directories
- `skills/`: Claude skill definitions

## Restore

Clone the repository and link the files into the home directory. [GNU Stow](https://www.gnu.org/software/stow/) is the intended tool:

```bash
git clone git@github.com:Arda-Aras103/DotfilesAndSkills.git ~/DotfilesAndSkills
cd ~/DotfilesAndSkills
stow -t ~ bash git
```

Then open a new shell, or run `source ~/.bashrc`.

Run `gh auth login` and `atuin import auto` again on the new machine. Credentials and shell history are not stored in this repository.

## Not included

The following are intentionally excluded. They hold credentials, private history, or machine-specific state:

- `~/.ssh/`, `~/.aws/`, `~/.docker/`
- `~/.bash_history`, `~/.lesshst`, `~/.local/share/atuin/`
- `~/.config/gh/hosts.yml` and any other token file
- Browser profiles, Steam libraries, and messaging app sessions
- Project source code (kept in separate repositories)

## Security

Before pushing, check that no secrets are tracked:

```bash
git ls-files | xargs grep -lEi 'token|secret|password|api[_-]?key' 2>/dev/null
```

Keep this repository private unless you have reviewed every file.
