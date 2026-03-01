#!/usr/bin/env bash
# Mastermind Donor Manager — update to latest v* release tag (run via systemd timer or manually)

set -euo pipefail

WORKDIR="/home/sdtdserverbf"
ACTIONS_LOG="${WORKDIR}/donation_actions.log"
VENV_PIP="${WORKDIR}/discord_bot/venv/bin/pip"
REQUIREMENTS="${WORKDIR}/discord_bot/requirements.txt"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UPDATE] $*" >> "$ACTIONS_LOG"
}

log_err() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UPDATE] ERROR: $*" >> "$ACTIONS_LOG"
  echo "ERROR: $*" >&2
}

cd "$WORKDIR"

if [[ ! -d .git ]]; then
  log_err "Not a git repo: $WORKDIR"
  exit 1
fi

if [[ -n $(git status --porcelain) ]]; then
  log_err "Working tree has local changes; refusing to update. Commit or stash first."
  exit 1
fi

log "Fetching tags..."
git fetch --tags --prune --force

LATEST_TAG=$(git tag --list 'v*' --sort=-v:refname | head -n 1 || true)
if [[ -z "$LATEST_TAG" ]]; then
  log_err "No v* tags found."
  exit 1
fi

log "Checking out tag: $LATEST_TAG"
git checkout "$LATEST_TAG"

if [[ -x "$VENV_PIP" && -f "$REQUIREMENTS" ]]; then
  log "Updating venv dependencies..."
  "$VENV_PIP" install -r "$REQUIREMENTS"
else
  log "WARNING: venv or requirements.txt missing; skipping pip install."
fi

log "Restarting 7dtd-discord-bot..."
sudo systemctl restart 7dtd-discord-bot

SHORT_SHA=$(git rev-parse --short HEAD)
log "Update complete: $LATEST_TAG ($SHORT_SHA)"
exit 0
