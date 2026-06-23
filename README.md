# laptop-setup

Backup and restore scripts for Mac dev environment (infra tooling).

## Tools covered

Go · Git · Claude Code · VS Code · Opencode · Lens · Helm · kubectl · k9s · Python · Oh My Zsh · GCP SDK · Homebrew

---

## On old laptop — create backup

```bash
cd ~/VSCodeProjects/laptop-setup
chmod +x backup.sh setup.sh
./backup.sh
```

This creates `~/Desktop/laptop-backup-YYYY-MM-DD.zip` and opens Finder.  
**Upload the zip to Google Drive manually** before wiping the laptop.

---

## On new laptop — restore

```bash
# 1. Install Xcode CLI tools (required for Homebrew/git)
xcode-select --install

# 2. Clone this repo
git clone <this-repo-url> ~/VSCodeProjects/laptop-setup
cd ~/VSCodeProjects/laptop-setup
chmod +x backup.sh setup.sh

# 3. Download the zip from Google Drive, then run:
./setup.sh ~/Downloads/laptop-backup-YYYY-MM-DD.zip
```

Follow the printed checklist at the end (GCP auth, kubectl contexts).

---

## What the zip contains

| Path in zip | Source |
|---|---|
| `configs/git/` | `~/.gitconfig`, `~/.gitignore_global` |
| `configs/zsh/` | aliases + OMZ theme/plugins (no secret env vars) |
| `configs/vscode/` | `settings.json` + `extensions.txt` |
| `configs/claude/` | `settings.json` (env values blanked) |
| `configs/opencode/` | `opencode.json` |
| `configs/ssh/` | `config` + private keys |
| `configs/gcp/` | service account JSON keys |
| `configs/kube/` | `~/.kube/config` |
| `packages/Brewfile` | all Homebrew formulas and casks |
| `secrets/env.sh` | secret env vars extracted from `.zshrc` |
| `secrets/corporate-ca.pem` | corporate CA certificate |

---

## Keeping it fresh

Re-run `./backup.sh` whenever you add tools or change configs.  
Upload the new zip to Google Drive (keep last 2 versions).
