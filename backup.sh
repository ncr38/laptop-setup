#!/usr/bin/env bash
# Collects all configs and secrets into a zip for GDrive upload.
# Run on your OLD laptop before switching.
set -euo pipefail

DATE=$(date +%Y-%m-%d)
BACKUP_NAME="laptop-backup-$DATE"
STAGING="/tmp/$BACKUP_NAME"
DEST="$HOME/Desktop/$BACKUP_NAME.zip"

log()  { echo "==> $*"; }
warn() { echo "WARN: $*" >&2; }

cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

mkdir -p "$STAGING"/{configs/{git,zsh,vscode,claude,opencode,ssh,gcp,kube},packages,secrets}

# ── Homebrew ──────────────────────────────────────────────────────────────────
log "Homebrew packages..."
brew bundle dump --file="$STAGING/packages/Brewfile" --force

# ── VS Code ───────────────────────────────────────────────────────────────────
log "VS Code extensions + settings..."
code --list-extensions > "$STAGING/configs/vscode/extensions.txt"
cp ~/Library/Application\ Support/Code/User/settings.json "$STAGING/configs/vscode/settings.json"

# ── Git ───────────────────────────────────────────────────────────────────────
log "Git config..."
cp ~/.gitconfig "$STAGING/configs/git/.gitconfig"
[ -f ~/.gitignore_global ] && cp ~/.gitignore_global "$STAGING/configs/git/.gitignore_global"

# ── Zsh — safe portions (aliases, theme, plugins, tool paths) ─────────────────
log "Zsh aliases + safe config..."
grep -E "^alias " ~/.zshrc > "$STAGING/configs/zsh/aliases.zsh" 2>/dev/null \
  || printf "# no aliases\n" > "$STAGING/configs/zsh/aliases.zsh"

{
  echo "# Oh My Zsh — safe config (no secrets)"
  echo ""
  THEME=$(grep "^ZSH_THEME=" ~/.zshrc | head -1 | cut -d'"' -f2 || true)
  [ -n "$THEME" ] && echo "ZSH_THEME=\"$THEME\""
  echo ""
  sed -n '/^plugins=(/,/^)/p' ~/.zshrc 2>/dev/null || true
  echo ""
  echo "# Tool paths (no credentials)"
  grep "^export PATH" ~/.zshrc 2>/dev/null \
    | grep -v -iE "(token|key|secret|password|credential|api_|auth)" || true
  echo ""
  grep -E "^export GOPRIVATE" ~/.zshrc 2>/dev/null || true
} > "$STAGING/configs/zsh/rc-safe.zsh"

# ── Secrets: env vars from .zshrc ─────────────────────────────────────────────
log "Secret env vars (from .zshrc)..."
{
  echo "# Secret env vars — extracted from ~/.zshrc"
  echo "# Source this in ~/.zshrc: source \"\$HOME/secrets/env.sh\""
  echo ""
  grep "^export " ~/.zshrc 2>/dev/null \
    | grep -iE "(token|key|secret|password|credential|api_|auth|base_url|model)" || true
} > "$STAGING/secrets/env.sh"

# ── Claude settings (env values stripped — actual values are in env.sh above) ─
log "Claude settings..."
python3 - <<PYEOF
import json, os
path = os.path.expanduser("~/.claude/settings.json")
with open(path) as f:
    data = json.load(f)
if "env" in data:
    data["env"] = {k: "" for k in data["env"]}
out = "$STAGING/configs/claude/settings.json"
with open(out, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

# ── Opencode config ───────────────────────────────────────────────────────────
log "Opencode config..."
cp ~/.config/opencode/opencode.json "$STAGING/configs/opencode/opencode.json"

# ── SSH ───────────────────────────────────────────────────────────────────────
log "SSH config + keys..."
[ -f ~/.ssh/config ] && cp ~/.ssh/config "$STAGING/configs/ssh/config"
for key in ~/.ssh/id_* ~/.ssh/bastion_key ~/.ssh/*.pem 2>/dev/null; do
  [ -f "$key" ] && cp "$key" "$STAGING/configs/ssh/" && chmod 600 "$STAGING/configs/ssh/$(basename $key)"
done

# ── GCP service account keys ──────────────────────────────────────────────────
log "GCP keys..."
if [ -d ~/.gcp/keys ]; then
  cp -r ~/.gcp/keys/. "$STAGING/configs/gcp/"
else
  warn "~/.gcp/keys not found — skipping"
fi

# ── Kubectl config ────────────────────────────────────────────────────────────
log "Kubectl config..."
[ -f ~/.kube/config ] && cp ~/.kube/config "$STAGING/configs/kube/config" \
  || warn "~/.kube/config not found — skipping"

# ── Corporate CA cert ─────────────────────────────────────────────────────────
[ -f ~/corporate-ca.pem ] && cp ~/corporate-ca.pem "$STAGING/secrets/corporate-ca.pem" \
  && log "Corporate CA cert..."

# ── Zip ───────────────────────────────────────────────────────────────────────
log "Creating zip..."
(cd /tmp && zip -qr "$DEST" "$BACKUP_NAME")

echo ""
echo "══════════════════════════════════════════════════"
echo "  Backup zip: $DEST"
echo "══════════════════════════════════════════════════"
echo ""
echo "Upload this file to Google Drive before wiping your laptop."
echo ""

# Open Desktop in Finder so you can drag to GDrive
open -R "$DEST"
