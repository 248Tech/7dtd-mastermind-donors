# Architecture: Mastermind Donor Manager

## Add-donor flow

1. **Discord**  
   A user with the **"Server Admin"** role sends a command: `!addvip` or `!addadmin` (or the same flow can be triggered by calling the CLI script directly).

2. **bot.py**  
   The Discord bot (discord.py, commands extension) validates arguments (steamid numeric, days ≥ 1, etc.), then runs the add-donor script via **subprocess** (no shell):

   - `subprocess.run(["/home/sdtdserverbf/add_donor.sh", username, steamid, days, joinmsg, namecolor, prefix, prefixcolor, type], shell=False, ...)`

3. **add_donor.sh**  
   The bash script:

   - Validates args and computes expiry and permission level (admin ⇒ 0, vip ⇒ 10).
   - **Removes** any existing donor entries for that Steam ID to avoid duplicates:
     - Deletes `//Player[@Id="Steam_<steamid>"]` from all five ServerTools XMLs in `BASE`.
     - Deletes `//user[@userid="<steamid>"]` from `serveradmin.xml`.
   - **Adds** new entries with **xmlstarlet** `ed -L`:
     - **LandClaimCount.xml**: `<Player Id="Steam_..." Name="..." Limit="4" />`
     - **ReservedSlots.xml**: `<Player ... Expires="<expiry>" />`
     - **LoginNotice.xml**: `<Player ... Message="<joinmsg>" Expiry="<expiry>" />`
     - **ChatColor.xml**: `<Player ... NameColor, Prefix, PrefixColor, Expires />`
     - **HighPingImmunity.xml**: `<Player Id="..." Name="..." />`
     - **serveradmin.xml** (under `/adminTools/users`): `<user platform="Steam" userid="..." name="..." permission_level="..." />`

4. **Logging**  
   The script appends timestamped lines to `donation_actions.log` (start, each major edit, success/failure). The bot logs command invocations to `discord_bot/bot.log` (no token).

So the end-to-end path is: **Discord command → bot.py → subprocess → add_donor.sh → xmlstarlet** modifies the five ServerTools XMLs and `serveradmin.xml`.

---

## Cleanup flow

1. **Trigger**  
   Either the Discord command `!cleanup` or a **cron** job (e.g. daily at 03:00) runs `cleanup_expired.sh`.

2. **cleanup_expired.sh**  
   - Sets `NOW=$(date "+%Y-%m-%d %H:%M:%S")`.
   - Reads **ReservedSlots.xml** and finds all `<Player>` nodes that have an `Expires` attribute **less than** `NOW` (string comparison).
   - For each such player, extracts the numeric Steam ID (after `Steam_`).
   - For each expired Steam ID:
     - **Removes** `//Player[@Id="Steam_<id>"]` from the five ServerTools XMLs (LandClaimCount, ReservedSlots, LoginNotice, ChatColor, HighPingImmunity).
     - **Removes** `//user[@userid="<id>"]` from `serveradmin.xml`.
   - Logs each removal to `donation_cleanup.log`. If `ReservedSlots.xml` is missing, the script exits non-zero; other missing files are logged and the script continues.

So: **ReservedSlots Expires < NOW → remove Player and user nodes** across the five config files and serveradmin.xml.
