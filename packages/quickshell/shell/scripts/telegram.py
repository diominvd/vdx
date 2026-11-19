#!/usr/bin/env python3
"""Notifications › Telegram. One JSON reply per command; JSON input uses stdin.

    telegram.py status                 local connection state, never credentials
    telegram.py connect                {token}: validate and create a pairing link
    telegram.py renew                  create a fresh link using the saved bot
    telegram.py pair                   check one page of updates for our /start code
    telegram.py disconnect             remove only Telegram keys
    telegram.py test                    send a test to the paired private chat
    telegram.py send                    {text, silent}: send a plain-text notification

Credentials and temporary pairing keys live in ~/.config/secrets/env, already
covered by private/manifest.json's secrets/env. Other keys/comments are preserved.
No daemon, polling, dependency, credential in argv or remote error text in replies.
"""
import fcntl, json, os, re, secrets, shlex, sys, tempfile, time
import urllib.error, urllib.request
from contextlib import contextmanager
from pathlib import Path

from backend import out, fail

SECRETS = Path.home() / ".config/secrets/env"
PREFIX = "VDX_TELEGRAM_"
KEYS = ("TOKEN", "USERNAME", "CHAT_ID", "PAIR_CODE", "PAIR_CREATED", "PAIR_OFFSET")
ASSIGNMENT = re.compile(r"^\s*(?:export\s+)?(" + PREFIX + r"(?:" + "|".join(KEYS) + r"))\s*=")
TOKEN = re.compile(r"[0-9]{5,16}:[A-Za-z0-9_-]{30,100}")
USERNAME = re.compile(r"[A-Za-z0-9_]{5,32}")
PAIR_SECONDS = 600
TIMEOUT = 12
MAX_INPUT = 32768


class TelegramError(RuntimeError):
    def __init__(self, message, retry_after=0):
        super().__init__(message)
        self.retry_after = retry_after


def read_env():
    try:
        return SECRETS.read_text()
    except FileNotFoundError:
        return ""


def credentials():
    values = {}
    for line in read_env().splitlines():
        match = ASSIGNMENT.match(line)
        if not match:
            continue
        try:
            parts = shlex.split(line[match.end():], comments=True)
        except ValueError:
            raise RuntimeError("Invalid Telegram credentials: reconnect the bot") from None
        if len(parts) > 1:
            raise RuntimeError("Invalid Telegram credentials: reconnect the bot")
        values[match[1][len(PREFIX):]] = parts[0] if parts else ""
    return values


@contextmanager
def locked():
    SECRETS.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(SECRETS.with_suffix(".lock"), os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def save(values):
    """Replace just our literal assignments, atomically and owner-readable only."""
    lines = [line for line in read_env().splitlines(keepends=True) if not ASSIGNMENT.match(line)]
    text = "".join(lines)
    if text and not text.endswith("\n"):
        text += "\n"
    text += "".join(f"export {PREFIX}{key}={shlex.quote(str(values[key]))}\n" for key in KEYS if values.get(key))
    fd, name = tempfile.mkstemp(prefix=".telegram-", dir=SECRETS.parent)
    try:
        with os.fdopen(fd, "w") as target:
            target.write(text)
            target.flush()
            os.fsync(target.fileno())
        os.replace(name, SECRETS)
    finally:
        Path(name).unlink(missing_ok=True)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def call(token, method, payload=None):
    if not TOKEN.fullmatch(token):
        raise TelegramError("Invalid bot token")
    request = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/{method}",
        data=json.dumps(payload or {}).encode(), headers={"Content-Type": "application/json"}, method="POST")
    try:
        # A redirect must never take a token-bearing URL to another host.
        with urllib.request.build_opener(NoRedirect).open(request, timeout=TIMEOUT) as response:
            result = json.loads(response.read(1024 * 1024))
    except urllib.error.HTTPError as exc:
        with exc:  # close error responses too; their URLs contain the bot token
            if exc.code == 429:
                try:
                    delay = json.loads(exc.read(8192)).get("parameters", {}).get("retry_after", 30)
                    delay = min(3600, max(1, int(delay)))
                except (ValueError, TypeError, AttributeError):
                    delay = 30
                raise TelegramError("Telegram rate limit: try again later", delay) from None
            messages = {401: "Telegram rejected the bot token", 403: "Open the bot and unblock it in Telegram",
                        409: "Bot updates are in use: stop its webhook or other polling client"}
            raise TelegramError(messages.get(exc.code, "Telegram request failed")) from None
    except (OSError, ValueError):
        raise TelegramError("Could not reach Telegram or read its reply") from None
    if not isinstance(result, dict) or result.get("ok") is not True or "result" not in result:
        raise TelegramError("Invalid reply from Telegram")
    return result["result"]


def active_pair(values):
    try:
        age = time.time() - int(values.get("PAIR_CREATED", "0"))
    except ValueError:
        return False
    return bool(re.fullmatch(r"[a-f0-9]{32}", values.get("PAIR_CODE", ""))) and 0 <= age < PAIR_SECONDS


def status(values):
    configured = bool(TOKEN.fullmatch(values.get("TOKEN", "")))
    username = values.get("USERNAME", "")
    if not USERNAME.fullmatch(username):
        username = ""
    pairing = configured and bool(username) and active_pair(values)
    return {"ok": True, "configured": configured, "connected": configured and bool(re.fullmatch(r"[1-9][0-9]*", values.get("CHAT_ID", ""))),
            "username": username, "pairUrl": f"https://t.me/{username}?start={values['PAIR_CODE']}" if pairing else ""}


def connect(payload):
    token = payload.get("token", "")
    if not isinstance(token, str) or not TOKEN.fullmatch(token.strip()):
        raise TelegramError("Enter a valid bot token from BotFather")
    token = token.strip()
    bot = call(token, "getMe")
    if not isinstance(bot, dict) or bot.get("is_bot") is not True or not USERNAME.fullmatch(str(bot.get("username", ""))):
        raise TelegramError("Telegram did not return a bot")
    values = {"TOKEN": token, "USERNAME": bot["username"], "PAIR_CODE": secrets.token_hex(16), "PAIR_CREATED": str(int(time.time()))}
    save(values)
    return status(values)


def renew(values):
    current = status(values)
    if not current["configured"] or not current["username"]:
        raise TelegramError("Connect a bot before creating a chat link")
    if current["connected"]:
        raise TelegramError("This bot already has a linked chat")
    values = {key: values[key] for key in ("TOKEN", "USERNAME")}
    values.update(PAIR_CODE=secrets.token_hex(16), PAIR_CREATED=str(int(time.time())))
    save(values)
    return status(values)


def pair(values):
    if not active_pair(values):
        raise TelegramError("Chat link expired: create a new link to continue")
    try:
        offset = int(values.get("PAIR_OFFSET", "0"))
    except ValueError:
        offset = 0
    updates = call(values.get("TOKEN", ""), "getUpdates", {"offset": offset, "limit": 100, "timeout": 0, "allowed_updates": ["message"]})
    if not isinstance(updates, list):
        raise TelegramError("Invalid reply from Telegram")
    for update in updates:
        if not isinstance(update, dict) or type(update.get("update_id")) is not int:
            continue
        offset = max(offset, update["update_id"] + 1)
        message = update.get("message")
        if not isinstance(message, dict):
            continue
        chat, sender = message.get("chat"), message.get("from")
        if not isinstance(chat, dict) or not isinstance(sender, dict):
            continue
        date = message.get("date")
        if (chat.get("type") == "private" and type(chat.get("id")) is int and chat["id"] > 0
                and sender.get("id") == chat["id"] and sender.get("is_bot") is False
                and type(date) is int and int(values["PAIR_CREATED"]) <= date <= time.time() + 30
                and message.get("text") == "/start " + values["PAIR_CODE"]):
            values = {key: values[key] for key in ("TOKEN", "USERNAME")}
            values["CHAT_ID"] = str(chat["id"])
            save(values)
            return status(values)
    values["PAIR_OFFSET"] = str(offset)
    save(values)
    raise TelegramError("No matching Start yet. Open your chat using this link, press Start, then finish connecting here.")


def send(values, payload):
    if not status(values)["connected"]:
        raise TelegramError("Connect a private Telegram chat first")
    text = payload.get("text")
    if not isinstance(text, str) or not text.strip():
        raise TelegramError("Notification text is empty")
    # UTF-16 units bound both Telegram's text limit and supplementary characters.
    text = text.encode("utf-16-le", errors="replace")[:8000].decode("utf-16-le", errors="ignore")
    call(values["TOKEN"], "sendMessage", {"chat_id": values["CHAT_ID"], "text": text,
         "disable_notification": payload.get("silent") is True, "link_preview_options": {"is_disabled": True}})
    return {"ok": True}


def dispatch(command, payload):
    if command == "connect":
        return connect(payload)
    if command == "disconnect":
        save({})
        return status({})
    values = credentials()
    if command == "status":
        return status(values)
    if command == "pair":
        return pair(values)
    if command == "renew":
        return renew(values)
    if command == "test":
        return send(values, {"text": "vdx · Telegram notifications are connected", "silent": False})
    if command == "send":
        return send(values, payload)
    raise RuntimeError("Unknown Telegram command")


def main():
    if len(sys.argv) != 2:
        fail("usage: telegram.py status|connect|renew|pair|disconnect|test|send")
    try:
        payload = {}
        if sys.argv[1] in ("connect", "send"):
            raw = sys.stdin.read(MAX_INPUT + 1)
            if len(raw) > MAX_INPUT:
                raise ValueError
            payload = json.loads(raw)
            if not isinstance(payload, dict):
                raise ValueError
        if sys.argv[1] == "status":
            result = dispatch("status", payload)  # read-only; no idle files or processes
        else:
            with locked():
                result = dispatch(sys.argv[1], payload)
        out(result)
    except TelegramError as exc:
        out({"ok": False, "error": str(exc), "retryAfter": exc.retry_after})
    except RuntimeError as exc:
        fail(str(exc))
    except (OSError, ValueError):
        fail("Could not read or save Telegram settings")


if __name__ == "__main__":
    main()
