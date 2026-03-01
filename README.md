# 🧠 Mastermind Donor Manager

Power donor management tool for 7 Days to Die server admins using ServerTools. Part of the upcoming Mastermind suite.

## Features

- **Add donors (VIP or Admin)** via Discord or CLI: updates LandClaimCount, ReservedSlots, LoginNotice, ChatColor, HighPingImmunity, and serveradmin.xml.
- **Expiry-based cleanup**: cron job removes expired donors using `ReservedSlots.xml` `Expires` timestamps.
- **Discord bot**: role-restricted commands (`!addvip`, `!addadmin`, `!cleanup`) for server admins.
- **Hardened bash scripts**: `set -euo pipefail`, validation, structured logging, no interactive prompts.

## Requirements

- **OS**: Ubuntu/Debian (bash, GNU date)
- **Packages**: `python3`, `python3-pip`, `xmlstarlet`
- **Python**: `discord.py`, `python-dotenv`
- **7 Days to Die** server with **ServerTools** mod; config path under `serverfiles/Mods/ServerTools_Config`.

## Target Server Layout

Deploy under the server user’s home so scripts and bot can read/write config and logs:

```
/home/sdtdserverbf/
├── add_donor.sh
├── cleanup_expired.sh
├── discord_bot/
│   ├── bot.py
│   └── .env          ← create from .env.example (do not commit)
├── donation_actions.log
├── donation_cleanup.log
└── (ServerTools config and 7DTD saves elsewhere; see paths below)
```

**Paths used by scripts (must exist on server):**

- **BASE** (ServerTools config): `/home/sdtdserverbf/serverfiles/Mods/ServerTools_Config`  
  Files: `LandClaimCount.xml`, `ReservedSlots.xml`, `LoginNotice.xml`, `HighPingImmunity.xml`, `ChatColor.xml`
- **SAVEADMIN**: `/home/sdtdserverbf/.local/share/7DaysToDie/Saves/serveradmin.xml`
- **Logs**: `donation_actions.log`, `donation_cleanup.log` in `/home/sdtdserverbf/`

## Installation

1. **Install OS and Python dependencies**

   ```bash
   sudo apt-get update
   sudo apt-get install -y python3 python3-pip xmlstarlet
   pip3 install --user discord.py python-dotenv
   ```

2. **Deploy files** to `/home/sdtdserverbf/` (e.g. clone repo or copy):
   - `add_donor.sh`, `cleanup_expired.sh`
   - `discord_bot/bot.py`, `discord_bot/.env.example`

3. **Create `.env`** from the example (do not commit real `.env`):

   ```bash
   cp /home/sdtdserverbf/discord_bot/.env.example /home/sdtdserverbf/discord_bot/.env
   # Edit .env and set DISCORD_TOKEN=your_bot_token
   ```

4. **Permissions**

   ```bash
   sudo chown -R sdtdserverbf:sdtdserverbf /home/sdtdserverbf
   sudo chmod 750 /home/sdtdserverbf/add_donor.sh
   sudo chmod 750 /home/sdtdserverbf/cleanup_expired.sh
   sudo chmod 750 /home/sdtdserverbf/discord_bot
   touch /home/sdtdserverbf/donation_actions.log /home/sdtdserverbf/donation_cleanup.log
   sudo chown sdtdserverbf:sdtdserverbf /home/sdtdserverbf/donation_actions.log /home/sdtdserverbf/donation_cleanup.log
   chmod 640 /home/sdtdserverbf/donation_actions.log /home/sdtdserverbf/donation_cleanup.log
   chmod 600 /home/sdtdserverbf/discord_bot/.env
   ```

5. **systemd** and **cron** (see below).

## Quick Start

Copy/paste deployment on a fresh server (replace `your-server` and paths if needed):

```bash
# 1) Copy repo files to server (from your machine)
scp -r add_donor.sh cleanup_expired.sh discord_bot systemd docs README.md LICENSE .gitignore your-server:/tmp/mastermind-donor/
# Or: rsync -av --exclude='.git' . your-server:/tmp/mastermind-donor/

# 2) On the server: move into place
sudo mv /tmp/mastermind-donor/add_donor.sh /tmp/mastermind-donor/cleanup_expired.sh /home/sdtdserverbf/
sudo mv /tmp/mastermind-donor/discord_bot /home/sdtdserverbf/

# 3) Create .env from example
cp /home/sdtdserverbf/discord_bot/.env.example /home/sdtdserverbf/discord_bot/.env
nano /home/sdtdserverbf/discord_bot/.env   # set DISCORD_TOKEN=...

# 4) Permissions
sudo chown -R sdtdserverbf:sdtdserverbf /home/sdtdserverbf
sudo chmod 750 /home/sdtdserverbf/add_donor.sh /home/sdtdserverbf/cleanup_expired.sh /home/sdtdserverbf/discord_bot
touch /home/sdtdserverbf/donation_actions.log /home/sdtdserverbf/donation_cleanup.log
sudo chown sdtdserverbf:sdtdserverbf /home/sdtdserverbf/donation_actions.log /home/sdtdserverbf/donation_cleanup.log
chmod 640 /home/sdtdserverbf/donation_actions.log /home/sdtdserverbf/donation_cleanup.log
chmod 600 /home/sdtdserverbf/discord_bot/.env

# 5) systemd
sudo cp /tmp/mastermind-donor/systemd/7dtd-discord-bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now 7dtd-discord-bot
sudo systemctl status 7dtd-discord-bot
journalctl -u 7dtd-discord-bot -f

# 6) Cron (daily cleanup at 03:00)
sudo crontab -u sdtdserverbf -e
# Add line:
# 0 3 * * * /home/sdtdserverbf/cleanup_expired.sh
```

## systemd Service

A unit file is provided at `systemd/7dtd-discord-bot.service`. Install and run:

```bash
sudo cp systemd/7dtd-discord-bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now 7dtd-discord-bot
sudo systemctl status 7dtd-discord-bot
journalctl -u 7dtd-discord-bot -f
```

The service runs as user `sdtdserverbf`, uses `EnvironmentFile=/home/sdtdserverbf/discord_bot/.env`, and is hardened (e.g. `NoNewPrivileges=true`, `ProtectSystem=full`, `ReadWritePaths=/home/sdtdserverbf`).

## Cron Cleanup

Run expired-donor cleanup daily (e.g. 03:00):

```bash
crontab -u sdtdserverbf -e
```

Add:

```
0 3 * * * /home/sdtdserverbf/cleanup_expired.sh
```

## Discord Commands

Only members with the **"Server Admin"** role can use the bot.

| Command | Description |
|--------|-------------|
| `!addvip username steamid days namecolor prefix prefixcolor join message here` | Add VIP donor; `join message` can contain spaces. |
| `!addadmin username steamid days namecolor prefix prefixcolor join message here` | Add admin donor (same args). |
| `!cleanup` | Run expired-donor cleanup now. |

Validation: `steamid` numeric, `days` numeric and ≥ 1 (max 3650). The bot calls `add_donor.sh` and `cleanup_expired.sh` via subprocess and reports success or stderr on failure.

## Security Design

- **Token**: Stored only in `.env`; repo contains only `.env.example`. systemd loads `.env` via `EnvironmentFile`.
- **Role restriction**: Commands are restricted to the Discord role **"Server Admin"**.
- **No shell=True**: Bot runs scripts with `subprocess.run(..., shell=False)` and full paths.
- **Script hardening**: Bash scripts use `set -euo pipefail`; inputs validated; XML escaped for attributes.
- **Service hardening**: systemd unit uses `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=full`, `ReadWritePaths` limited to `/home/sdtdserverbf`.

# ⚠️ Important Installation Clarifications (Real-World Deployment Notes)

The following issues were encountered during a full production deployment on Debian 12 (Bookworm). These steps clarify requirements not fully explained in the original Quick Start.

---

## 1️⃣ systemd Path Correction

The Quick Start references:

    sudo cp /tmp/mastermind-donor/systemd/7dtd-discord-bot.service /etc/systemd/system/

This path only works if the repo was copied into /tmp using SCP.

If cloned normally:

    git clone https://github.com/248Tech/7dtd-mastermind-donors
    cd 7dtd-mastermind-donors

The correct command is:

    sudo cp systemd/7dtd-discord-bot.service /etc/systemd/system/

Then:

    sudo systemctl daemon-reload
    sudo systemctl enable --now 7dtd-discord-bot

---

## 2️⃣ Python Virtual Environment Is REQUIRED (Recommended)

The bot will fail with:

    ModuleNotFoundError: No module named 'discord'

Unless dependencies are installed.

Recommended setup:

    cd /home/sdtdserverbf/discord_bot
    python3 -m venv venv
    ./venv/bin/pip install -r requirements.txt

Then update systemd ExecStart to:

    ExecStart=/home/sdtdserverbf/discord_bot/venv/bin/python /home/sdtdserverbf/discord_bot/bot.py

Reload:

    sudo systemctl daemon-reload
    sudo systemctl restart 7dtd-discord-bot

Without this, system Python will not see discord.py.

---

## 3️⃣ Required Discord Privileged Gateway Intents

Because the bot uses:

    intents.message_content = True
    intents.members = True

You MUST enable BOTH in the Discord Developer Portal:

Developer Portal → Bot → Privileged Gateway Intents

Enable:
- Message Content Intent
- Server Members Intent

If not enabled:
- Prefix commands will not trigger
- Role checks may silently fail

---

## 4️⃣ Role Name Must Match EXACTLY

The bot restricts commands to:

    REQUIRED_ROLE = "Server Admin"

This role must:
- Exist in Discord
- Match case and spacing exactly
- Be assigned to the user running commands

Otherwise users will see:

    Only members with the role "Server Admin" can use this command.

---

## 5️⃣ Channel Permissions Can Block the Bot

Even if the bot is online and invited correctly, it will fail with:

    403 Forbidden (error code: 50013): Missing Permissions

If it lacks channel-level permissions.

In each channel the bot operates in, ensure:

- View Channel
- Send Messages
- Read Message History

Channel overrides can block the bot even if server role permissions allow it.

---

## 6️⃣ Use sudo for systemd Logs

Running:

    journalctl -u 7dtd-discord-bot -f

Will not show logs without permission.

Correct:

    sudo journalctl -u 7dtd-discord-bot -f

---

## 7️⃣ Final Verification Checklist

Working state should show:

    sudo systemctl status 7dtd-discord-bot

Active: active (running)

And logs:

    discord.gateway: Shard ID None has connected to Gateway

Then in Discord:

    !cleanup

Should respond without permission or 403 errors.

---

## 8️⃣ Recommended Improvements

For production stability:

- Always use a Python virtual environment
- Explicitly document required gateway intents
- Clarify systemd path usage
- Add a troubleshooting section to README
- Consider allowing multiple admin roles instead of single hardcoded role

---

## License

MIT. See [LICENSE](LICENSE).

## Disclaimer

This tool is not affiliated with 7 Days to Die or ServerTools. Use at your own risk. Back up config and save files before use.

## Mastermind Roadmap

Mastermind Donor Manager is the first component of the **Mastermind** suite for 7 Days to Die server management. Planned additions may include more automation, reporting, and integration with other server tools.
