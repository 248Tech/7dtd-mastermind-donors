#!/usr/bin/env python3
"""
7DTD Donor Discord Bot - Role-restricted commands to add VIP/admin and run cleanup.
Loads DISCORD_TOKEN from .env (python-dotenv) or systemd EnvironmentFile.
"""

import asyncio
import logging
import os
import subprocess
from pathlib import Path

import discord
from discord.ext import commands
from dotenv import load_dotenv

# Paths
HOME = "/home/sdtdserverbf"
ADD_DONOR = f"{HOME}/add_donor.sh"
CLEANUP = f"{HOME}/cleanup_expired.sh"
BOT_LOG = f"{HOME}/discord_bot/bot.log"
REQUIRED_ROLE = "Server Admin"
MAX_DAYS = 3650
SCRIPT_TIMEOUT = 30
STDERR_TRUNCATE = 500

# Load .env from bot directory (also allow systemd to set DISCORD_TOKEN via EnvironmentFile)
load_dotenv(Path(__file__).resolve().parent / ".env")

# Logging to file only; never log token
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[logging.FileHandler(BOT_LOG, encoding="utf-8")],
)
logger = logging.getLogger(__name__)


def get_token() -> str:
    token = os.environ.get("DISCORD_TOKEN", "").strip()
    if not token:
        raise ValueError("DISCORD_TOKEN not set (check .env or EnvironmentFile)")
    return token


def has_admin_role(member: discord.Member) -> bool:
    return any(r.name == REQUIRED_ROLE for r in (member.roles or []))


def check_admin_role():
    def predicate(ctx):
        if not ctx.guild or not ctx.author:
            raise commands.CheckFailure("This command can only be used in a server.")
        if not isinstance(ctx.author, discord.Member):
            raise commands.CheckFailure("Could not resolve member.")
        if not has_admin_role(ctx.author):
            raise commands.CheckFailure(f'Only members with the role "{REQUIRED_ROLE}" can use this command.')
        return True
    return commands.check(predicate)


# Bot setup with message_content for prefix commands
intents = discord.Intents.default()
intents.message_content = True
intents.members = True

bot = commands.Bot(command_prefix="!", intents=intents)


@bot.event
async def on_ready():
    logger.info("Bot ready: %s (id %s)", bot.user, bot.user.id if bot.user else None)


@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.CheckFailure):
        await ctx.send(str(error))
        return
    logger.exception("Command error: %s", error)
    await ctx.send(f"An error occurred: {error!s}")


def run_add_donor(args: list[str]) -> subprocess.CompletedProcess:
    if not os.path.isfile(ADD_DONOR):
        raise FileNotFoundError(f"Script not found: {ADD_DONOR}")
    return subprocess.run(
        [ADD_DONOR] + args,
        shell=False,
        text=True,
        capture_output=True,
        timeout=SCRIPT_TIMEOUT,
        cwd=HOME,
    )


def run_cleanup() -> subprocess.CompletedProcess:
    if not os.path.isfile(CLEANUP):
        raise FileNotFoundError(f"Script not found: {CLEANUP}")
    return subprocess.run(
        [CLEANUP],
        shell=False,
        text=True,
        capture_output=True,
        timeout=SCRIPT_TIMEOUT,
        cwd=HOME,
    )


@bot.command(name="addvip")
@check_admin_role()
async def addvip(ctx, username: str, steamid: str, days: str, namecolor: str, prefix: str, prefixcolor: str, *, joinmsg: str = ""):
    """
    Add VIP donor: !addvip username steamid days namecolor prefix prefixcolor join message here
    """
    logger.info("addvip invoked by %s: username=%s steamid=%s days=%s", ctx.author, username, steamid, days)
    if not steamid.isdigit():
        await ctx.send("`steamid` must be numeric.")
        return
    if not days.isdigit() or int(days) < 1:
        await ctx.send("`days` must be a number >= 1.")
        return
    if int(days) > MAX_DAYS:
        await ctx.send(f"`days` cannot exceed {MAX_DAYS}.")
        return
    args = [username, steamid, days, joinmsg or "Welcome!", namecolor, prefix, prefixcolor, "vip"]
    try:
        result = await asyncio.get_event_loop().run_in_executor(None, run_add_donor, args)
    except FileNotFoundError as e:
        await ctx.send(str(e))
        return
    except subprocess.TimeoutExpired:
        await ctx.send("Script timed out.")
        return
    if result.returncode != 0:
        err = (result.stderr or result.stdout or "")[:STDERR_TRUNCATE]
        await ctx.send(f"Add donor failed (exit {result.returncode}):\n```\n{err}\n```")
        return
    expiry_note = f" Expires in {days} days."
    await ctx.send(f"VIP added for **{username}** (Steam ID `{steamid}`).{expiry_note}")


@bot.command(name="addadmin")
@check_admin_role()
async def addadmin(ctx, username: str, steamid: str, days: str, namecolor: str, prefix: str, prefixcolor: str, *, joinmsg: str = ""):
    """
    Add admin donor: !addadmin username steamid days namecolor prefix prefixcolor join message here
    """
    logger.info("addadmin invoked by %s: username=%s steamid=%s days=%s", ctx.author, username, steamid, days)
    if not steamid.isdigit():
        await ctx.send("`steamid` must be numeric.")
        return
    if not days.isdigit() or int(days) < 1:
        await ctx.send("`days` must be a number >= 1.")
        return
    if int(days) > MAX_DAYS:
        await ctx.send(f"`days` cannot exceed {MAX_DAYS}.")
        return
    args = [username, steamid, days, joinmsg or "Welcome!", namecolor, prefix, prefixcolor, "admin"]
    try:
        result = await asyncio.get_event_loop().run_in_executor(None, run_add_donor, args)
    except FileNotFoundError as e:
        await ctx.send(str(e))
        return
    except subprocess.TimeoutExpired:
        await ctx.send("Script timed out.")
        return
    if result.returncode != 0:
        err = (result.stderr or result.stdout or "")[:STDERR_TRUNCATE]
        await ctx.send(f"Add donor failed (exit {result.returncode}):\n```\n{err}\n```")
        return
    expiry_note = f" Expires in {days} days."
    await ctx.send(f"Admin donor added for **{username}** (Steam ID `{steamid}`).{expiry_note}")


@bot.command(name="cleanup")
@check_admin_role()
async def cleanup(ctx):
    """Run expired donor cleanup."""
    logger.info("cleanup invoked by %s", ctx.author)
    try:
        result = await asyncio.get_event_loop().run_in_executor(None, run_cleanup)
    except FileNotFoundError as e:
        await ctx.send(str(e))
        return
    except subprocess.TimeoutExpired:
        await ctx.send("Cleanup script timed out.")
        return
    if result.returncode != 0:
        err = (result.stderr or result.stdout or "")[:STDERR_TRUNCATE]
        await ctx.send(f"Cleanup failed (exit {result.returncode}):\n```\n{err}\n```")
        return
    await ctx.send("Cleanup completed successfully. Expired donors removed.")


def main():
    try:
        token = get_token()
    except ValueError as e:
        logger.critical("%s", e)
        raise SystemExit(1) from e
    bot.run(token)


if __name__ == "__main__":
    main()
