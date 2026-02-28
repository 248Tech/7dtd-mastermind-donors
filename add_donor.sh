#!/usr/bin/env bash
# 7DTD Donor Add Script - Non-interactive CLI
# Usage: add_donor.sh username steamid days joinmsg namecolor prefix prefixcolor type

set -euo pipefail

BASE="/home/sdtdserverbf/serverfiles/Mods/ServerTools_Config"
SAVEADMIN="/home/sdtdserverbf/.local/share/7DaysToDie/Saves/serveradmin.xml"
ACTIONS_LOG="/home/sdtdserverbf/donation_actions.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$ACTIONS_LOG"
}

log_err() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$ACTIONS_LOG"
  echo "ERROR: $*" >&2
}

usage() {
  echo "Usage: add_donor.sh username steamid days joinmsg namecolor prefix prefixcolor type"
  echo "  type: vip | admin"
  exit 1
}

# Escape string for use in XML attribute (minimal: & < > " ')
xml_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  s="${s//\'/&apos;}"
  printf '%s' "$s"
}

[[ $# -ge 8 ]] || usage

USERNAME="$1"
STEAMID="$2"
DAYS="$3"
JOINMSG="$4"
NAMECOLOR="$5"
PREFIX="$6"
PREFIXCOLOR="$7"
TYPE="${8,,}"

[[ "$TYPE" == "vip" || "$TYPE" == "admin" ]] || { usage; }
[[ "$STEAMID" =~ ^[0-9]+$ ]] || { log_err "steamid must be numeric: $STEAMID"; exit 1; }
[[ "$DAYS" =~ ^[0-9]+$ ]] || { log_err "days must be numeric: $DAYS"; exit 1; }
[[ $DAYS -ge 1 ]] || { log_err "days must be >= 1"; exit 1; }

if [[ "$TYPE" == "admin" ]]; then
  PERMISSION_LEVEL="0"
else
  PERMISSION_LEVEL="10"
fi

EXPIRY=$(date -d "+${DAYS} days" "+%Y-%m-%d %H:%M:%S")
STEAM_ID_ATTR="Steam_${STEAMID}"
JOINMSG_ESC=$(xml_escape "$JOINMSG")
USERNAME_ESC=$(xml_escape "$USERNAME")
PREFIX_ESC=$(xml_escape "$PREFIX")

log "START add_donor user=$USERNAME steamid=$STEAMID days=$DAYS type=$TYPE expiry=$EXPIRY"

# Remove existing entries to avoid duplicates
for xml in LandClaimCount.xml ReservedSlots.xml LoginNotice.xml ChatColor.xml HighPingImmunity.xml; do
  f="${BASE}/${xml}"
  if [[ -f "$f" ]]; then
    if xmlstarlet ed -L -d "//Player[@Id=\"${STEAM_ID_ATTR}\"]" "$f" 2>/dev/null; then
      log "Removed existing Player from $xml"
    fi
  else
    log "Skip remove (missing): $f"
  fi
done

if [[ -f "$SAVEADMIN" ]]; then
  if xmlstarlet ed -L -d "//user[@userid=\"${STEAMID}\"]" "$SAVEADMIN" 2>/dev/null; then
    log "Removed existing user from serveradmin.xml"
  fi
else
  log "Skip remove serveradmin (missing): $SAVEADMIN"
fi

# Add new entries
LANDCLAIM="${BASE}/LandClaimCount.xml"
RESERVED="${BASE}/ReservedSlots.xml"
LOGINNOTICE="${BASE}/LoginNotice.xml"
CHATCOLOR="${BASE}/ChatColor.xml"
HIGHPING="${BASE}/HighPingImmunity.xml"

for f in "$LANDCLAIM" "$RESERVED" "$LOGINNOTICE" "$CHATCOLOR" "$HIGHPING"; do
  if [[ ! -f "$f" ]]; then
    log_err "Required file missing: $f"
    exit 1
  fi
done

# LandClaimCount.xml: <Player Id="Steam_STEAMID" Name="USERNAME" Limit="4" />
# Add under root (root is often LandClaimCount or similar container)
xmlstarlet ed -L -s "/*" -t elem -n "Player" -v "" \
  -i "//Player[last()]" -t attr -n "Id" -v "$STEAM_ID_ATTR" \
  -i "//Player[last()]" -t attr -n "Name" -v "$USERNAME_ESC" \
  -i "//Player[last()]" -t attr -n "Limit" -v "4" \
  "$LANDCLAIM" || { log_err "Failed to edit LandClaimCount.xml"; exit 1; }
log "Added to LandClaimCount.xml"

# ReservedSlots.xml: <Player Id="..." Name="..." Expires="EXPIRY" />
xmlstarlet ed -L -s "/*" -t elem -n "Player" -v "" \
  -i "//Player[last()]" -t attr -n "Id" -v "$STEAM_ID_ATTR" \
  -i "//Player[last()]" -t attr -n "Name" -v "$USERNAME_ESC" \
  -i "//Player[last()]" -t attr -n "Expires" -v "$EXPIRY" \
  "$RESERVED" || { log_err "Failed to edit ReservedSlots.xml"; exit 1; }
log "Added to ReservedSlots.xml"

# LoginNotice.xml: Message="JOINMSG" Expiry="EXPIRY"
xmlstarlet ed -L -s "/*" -t elem -n "Player" -v "" \
  -i "//Player[last()]" -t attr -n "Id" -v "$STEAM_ID_ATTR" \
  -i "//Player[last()]" -t attr -n "Name" -v "$USERNAME_ESC" \
  -i "//Player[last()]" -t attr -n "Message" -v "$JOINMSG_ESC" \
  -i "//Player[last()]" -t attr -n "Expiry" -v "$EXPIRY" \
  "$LOGINNOTICE" || { log_err "Failed to edit LoginNotice.xml"; exit 1; }
log "Added to LoginNotice.xml"

# ChatColor.xml: NameColor, Prefix="(PREFIX)", PrefixColor, Expires
xmlstarlet ed -L -s "/*" -t elem -n "Player" -v "" \
  -i "//Player[last()]" -t attr -n "Id" -v "$STEAM_ID_ATTR" \
  -i "//Player[last()]" -t attr -n "Name" -v "$USERNAME_ESC" \
  -i "//Player[last()]" -t attr -n "NameColor" -v "$NAMECOLOR" \
  -i "//Player[last()]" -t attr -n "Prefix" -v "($PREFIX_ESC)" \
  -i "//Player[last()]" -t attr -n "PrefixColor" -v "$PREFIXCOLOR" \
  -i "//Player[last()]" -t attr -n "Expires" -v "$EXPIRY" \
  "$CHATCOLOR" || { log_err "Failed to edit ChatColor.xml"; exit 1; }
log "Added to ChatColor.xml"

# HighPingImmunity.xml: <Player Id="..." Name="..." />
xmlstarlet ed -L -s "/*" -t elem -n "Player" -v "" \
  -i "//Player[last()]" -t attr -n "Id" -v "$STEAM_ID_ATTR" \
  -i "//Player[last()]" -t attr -n "Name" -v "$USERNAME_ESC" \
  "$HIGHPING" || { log_err "Failed to edit HighPingImmunity.xml"; exit 1; }
log "Added to HighPingImmunity.xml"

# serveradmin.xml: <user platform="Steam" userid="STEAMID" name="USERNAME" permission_level="PERMISSION" />
if [[ -f "$SAVEADMIN" ]]; then
  # Ensure /adminTools/users exists (check node count, not text)
  if ! xmlstarlet sel -t -v "count(/adminTools/users)" "$SAVEADMIN" 2>/dev/null | grep -qE '^[1-9]'; then
    xmlstarlet ed -L -s "/*" -t elem -n "adminTools" -v "" \
      -s "/adminTools" -t elem -n "users" -v "" \
      "$SAVEADMIN" 2>/dev/null || true
  fi
  xmlstarlet ed -L -s "//adminTools/users" -t elem -n "user" -v "" \
    -i "//adminTools/users/user[last()]" -t attr -n "platform" -v "Steam" \
    -i "//adminTools/users/user[last()]" -t attr -n "userid" -v "$STEAMID" \
    -i "//adminTools/users/user[last()]" -t attr -n "name" -v "$USERNAME_ESC" \
    -i "//adminTools/users/user[last()]" -t attr -n "permission_level" -v "$PERMISSION_LEVEL" \
    "$SAVEADMIN" || { log_err "Failed to edit serveradmin.xml"; exit 1; }
  log "Added to serveradmin.xml"
else
  log_err "serveradmin.xml missing: $SAVEADMIN"
  exit 1
fi

log "SUCCESS add_donor user=$USERNAME steamid=$STEAMID expiry=$EXPIRY"
exit 0
