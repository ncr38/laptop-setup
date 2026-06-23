#!/usr/bin/env bash
# Restores your dev environment from a GDrive backup zip.
# Usage: ./setup.sh /path/to/laptop-backup-YYYY-MM-DD.zip
set -euo pipefail

ZIP="${1:-}"
if [ -z "$ZIP" ] || [ ! -f "$ZIP" ]; then
  echo "Usage: $0 /path/to/laptop-backup-YYYY-MM-DD.zip"
  echo ""
  echo "Download the zip from Google Drive first, then run this script."
  exit 1
fi

EXTRACT_DIR="/tmp/laptop-restore"
rm -rf "$EXTRACT_DIR" && mkdir -p "$EXTRACT_DIR"
unzip -q "$ZIP" -d "$EXTRACT_DIR"
# Handle single top-level dir inside zip
BACKUP_ROOT=$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
[ -z "$BACKUP_ROOT" ] && BACKUP_ROOT="$EXTRACT_DIR"

CONFIGS="$BACKUP_ROOT/configs"
PACKAGES="$BACKUP_ROOT/packages"
SECRETS="$BACKUP_ROOT/secrets"

log()  { echo "==> $*"; }
step() { echo ""; echo "── $* ──"; }

# ── Rosetta (Apple Silicon) ───────────────────────────────────────────────────
if [[ "$(uname -m)" == "arm64" ]]; then
  softwareupdate --install-rosetta --agree-to-license 2>/dev/null || true
fi

# ── Homebrew ──────────────────────────────────────────────────────────────────
step "Homebrew"
if ! command -v brew &>/dev/null; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
log "Installing packages from Brewfile..."
brew bundle install --file="$PACKAGES/Brewfile" --no-lock

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
step "Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# ── Git ───────────────────────────────────────────────────────────────────────
step "Git config"
cp "$CONFIGS/git/.gitconfig" ~/.gitconfig
[ -f "$CONFIGS/git/.gitignore_global" ] && cp "$CONFIGS/git/.gitignore_global" ~/.gitignore_global

# ── Zsh ───────────────────────────────────────────────────────────────────────
step "Zsh config"
MARKER="# laptop-setup-restored"
if ! grep -q "$MARKER" ~/.zshrc 2>/dev/null; then
  cat >> ~/.zshrc <<BLOCK

$MARKER
source "$HOME/.zsh/rc-safe.zsh"
source "$HOME/.zsh/aliases.zsh"
[ -f "$HOME/secrets/env.sh" ] && source "$HOME/secrets/env.sh"
BLOCK
  mkdir -p ~/.zsh
  cp "$CONFIGS/zsh/rc-safe.zsh" ~/.zsh/rc-safe.zsh
  cp "$CONFIGS/zsh/aliases.zsh" ~/.zsh/aliases.zsh
  log "Zsh config installed to ~/.zsh/"
fi

# ── VS Code ───────────────────────────────────────────────────────────────────
step "VS Code"
VSCODE_USER="$HOME/Library/Application Support/Code/User"
if command -v code &>/dev/null; then
  mkdir -p "$VSCODE_USER"
  cp "$CONFIGS/vscode/settings.json" "$VSCODE_USER/settings.json"
  log "Installing VS Code extensions..."
  while IFS= read -r ext; do
    [[ -z "$ext" || "$ext" == \#* ]] && continue
    code --install-extension "$ext" --force 2>/dev/null || true
  done < "$CONFIGS/vscode/extensions.txt"
else
  log "VS Code CLI not found — install VS Code first, then re-run"
fi

# ── Claude Code ───────────────────────────────────────────────────────────────
step "Claude Code"
if command -v claude &>/dev/null; then
  mkdir -p ~/.claude
  cp "$CONFIGS/claude/settings.json" ~/.claude/settings.json
fi

# ── Opencode ──────────────────────────────────────────────────────────────────
step "Opencode"
mkdir -p ~/.config/opencode
cp "$CONFIGS/opencode/opencode.json" ~/.config/opencode/opencode.json

# ── SSH ───────────────────────────────────────────────────────────────────────
step "SSH"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
[ -f "$CONFIGS/ssh/config" ] && cp "$CONFIGS/ssh/config" ~/.ssh/config && chmod 600 ~/.ssh/config
for key in "$CONFIGS"/ssh/id_* "$CONFIGS"/ssh/bastion_key "$CONFIGS"/ssh/*.pem 2>/dev/null; do
  [ -f "$key" ] && cp "$key" ~/.ssh/ && chmod 600 ~/.ssh/$(basename "$key")
done

# ── GCP ───────────────────────────────────────────────────────────────────────
step "GCP keys"
if [ -d "$CONFIGS/gcp" ] && [ "$(ls -A "$CONFIGS/gcp")" ]; then
  mkdir -p ~/.gcp/keys
  cp -r "$CONFIGS/gcp/". ~/.gcp/keys/
  log "GCP keys restored to ~/.gcp/keys/"
fi

# ── Kube ──────────────────────────────────────────────────────────────────────
step "Kubectl config"
if [ -f "$CONFIGS/kube/config" ]; then
  mkdir -p ~/.kube
  cp "$CONFIGS/kube/config" ~/.kube/config
  chmod 600 ~/.kube/config
fi

# ── Secrets: env vars ─────────────────────────────────────────────────────────
step "Secret env vars"
if [ -f "$SECRETS/env.sh" ]; then
  mkdir -p ~/secrets
  cp "$SECRETS/env.sh" ~/secrets/env.sh
  chmod 600 ~/secrets/env.sh
  log "env.sh installed to ~/secrets/env.sh (sourced from .zshrc)"
fi

# ── Corporate CA ──────────────────────────────────────────────────────────────
[ -f "$SECRETS/corporate-ca.pem" ] && cp "$SECRETS/corporate-ca.pem" ~/corporate-ca.pem

# ── Cleanup extract dir ───────────────────────────────────────────────────────
rm -rf "$EXTRACT_DIR"

# ── GCP auth (manual) ─────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════"
echo "  Restore complete. Remaining manual steps:"
echo "══════════════════════════════════════════════════"
echo ""
echo "  1. Open a NEW terminal (reload zsh config)"
echo ""
echo "  2. Authenticate GCP (if needed):"
echo "     gcloud init"
echo "     gcloud auth login"
echo "     gcloud auth application-default login"
echo ""
echo "  3. Reconnect kubectl cluster contexts:"
echo "     gcloud container clusters get-credentials <cluster> --region <region>"
echo ""
echo "  4. Install Lens from: https://k8slens.dev"
echo ""
echo "  5. Install iTerm2 from: https://iterm2.com"
echo ""
echo "Done."
