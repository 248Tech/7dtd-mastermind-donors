#!/usr/bin/env bash
# 7DTD Donor Cleanup - Remove expired entries from ServerTools configs

set -euo pipefail

BASE="/home/sdtdserverbf/serverfiles/Mods/ServerTools_Config"
SAVEADMIN="/home/sdtdserverbf/.local/share/7DaysToDie/Saves/serveradmin.xml"
RESERVED="${BASE}/ReservedSlots.xml"
CLEANUP_LOG="/home/sdtdserverbf/donation_cleanup.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$CLEANUP_LOG"
}

log_err() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$CLEANUP_LOG"
  echo "ERROR: $*" >&2
}

NOW=$(date "+%Y-%m-%d %H:%M:%S")
log "Cleanup started at $NOW"

# Critical file: must exist to determine expired IDs
if [[ ! -f "$RESERVED" ]]; then
  log_err "Critical file missing: $RESERVED"
  exit 1
fi

# Get expired Steam IDs: list Player with Expires, filter where Expires < NOW
EXPIRED_IDS=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  steam_id="${line%% *}"
  expiry="${line#* }"
  [[ "$expiry" < "$NOW" ]] || continue
  num="${steam_id#Steam_}"
  [[ "$num" =~ ^[0-9]+$ ]] && EXPIRED_IDS+=("$num")
done < <(xmlstarlet sel -t -m "//Player[@Expires]" -v "concat(@Id, ' ', @Expires)" -n "$RESERVED" 2>/dev/null || true)

# Remove duplicates
readarray -t UNIQ_IDS < <(printf '%s\n' "${EXPIRED_IDS[@]}" | sort -u)

for steamid in "${UNIQ_IDS[@]}"; do
  steam_attr="Steam_${steamid}"
  log "Removing expired: steamid=$steamid"

  for xml in LandClaimCount.xml ReservedSlots.xml LoginNotice.xml ChatColor.xml HighPingImmunity.xml; do
    f="${BASE}/${xml}"
    if [[ -f "$f" ]]; then
      if xmlstarlet ed -L -d "//Player[@Id=\"${steam_attr}\"]" "$f" 2>/dev/null; then
        log "  Removed from $xml"
      fi
    else
      log "  Skip (missing): $f"
    fi
  done

  if [[ -f "$SAVEADMIN" ]]; then
    if xmlstarlet ed -L -d "//user[@userid=\"${steamid}\"]" "$SAVEADMIN" 2>/dev/null; then
      log "  Removed from serveradmin.xml"
    fi
  else
    log "  Skip serveradmin (missing): $SAVEADMIN"
  fi
done

log "Cleanup done at $(date '+%Y-%m-%d %H:%M:%S')"
exit 0
