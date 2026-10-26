#!/usr/bin/env python3
"""Read-only Google Calendar sync for the u2b22.pomodoro Omarchy plugin.

Fetches today's timed events from one calendar, selected by display name, and
prints them as a single JSON object on stdout. Nothing is cached on disk: the
shell asks again every few minutes, and a failed request is reported as an
error rather than masked by old data.

The OAuth client comes from ~/.config/omarchy/u2b22-pomodoro/oauth.json when
that file exists. Otherwise Calendar Agenda's published desktop client is
fetched and cached, as Calendar Agenda itself does. The OAuth, token and
Calendar API code is adapted from Calendar Agenda
(io.github.alexinslc.calendar-agenda), MIT licensed. See LICENSE.

Usage:
    pomodoro_sync.py sync --calendar NAME
    pomodoro_sync.py connect
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import queue
import re
import secrets
import stat
import subprocess
import sys
import tempfile
import threading
import time as time_module
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from datetime import date, datetime, time, timedelta
from html.parser import HTMLParser
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any


CONFIG_PATH = Path.home() / ".config" / "omarchy" / "u2b22-pomodoro" / "oauth.json"
# Without a private client file, borrow Calendar Agenda's published desktop
# client, as that plugin does, and keep a private copy for a day.
REMOTE_CLIENT_URL = "https://omarchy.alexinslc.com/calendar-agenda/oauth/client-config"
REMOTE_CLIENT_MAX_BYTES = 4096
CLIENT_CACHE_PATH = (
    Path.home() / ".local" / "state" / "u2b22-pomodoro" / "oauth-client.json"
)
CLIENT_CACHE_MAX_AGE = 24 * 60 * 60
SECRET_SERVICE = "u2b22-pomodoro"
SECRET_ACCOUNT = "google"

AUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
CALENDAR_ENDPOINT = "https://www.googleapis.com/calendar/v3"
SCOPES = (
    "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
    "https://www.googleapis.com/auth/calendar.events.readonly",
)
CALLBACK_PATH = "/oauth2callback"
CLIENT_ID_RE = re.compile(r"^[^/\s]+\.apps\.googleusercontent\.com$")


class SyncError(RuntimeError):
    """An expected failure, reported to the shell as {ok: false, kind, error}.

    kind is one of:
      config    the OAuth client file is missing or invalid
      connect   no usable Google login; the panel offers Connect
      calendar  the selected calendar does not exist or is ambiguous
      network   Google could not be reached or answered with an error
      secret    the Secret Service keyring is unavailable
    """

    def __init__(self, kind: str, message: str):
        super().__init__(message)
        self.kind = kind


# ---------------------------------------------------------------- configuration


def parse_client(raw: Any, source: str) -> tuple[str, str]:
    """Read a client id and secret from any of the accepted shapes.

    Google Cloud's download ({"installed": {...}}), Calendar Agenda's published
    config ({"google": {...}}), or a flat {"client_id", "client_secret"}.
    """
    if not isinstance(raw, dict):
        raise SyncError("config", f"{source} must contain a JSON object")
    client = raw.get("installed", raw.get("google", raw))
    if not isinstance(client, dict):
        raise SyncError("config", f"{source} has no OAuth client object")
    client_id = client.get("client_id")
    client_secret = client.get("client_secret", "")
    if not isinstance(client_id, str) or not CLIENT_ID_RE.fullmatch(client_id):
        raise SyncError(
            "config", f"{source}: client_id must end in .apps.googleusercontent.com"
        )
    if not isinstance(client_secret, str):
        raise SyncError("config", f"{source}: client_secret must be a string")
    return client_id, client_secret


def _read_private_json(path: Path) -> Any:
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise SyncError("config", f"{path} is not a regular file")
    if info.st_mode & 0o077:
        raise SyncError("config", f"{path} must be private: chmod 600 it")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SyncError("config", f"{path} is not valid JSON") from error


def _fetch_remote_client() -> Any:
    request = urllib.request.Request(
        REMOTE_CLIENT_URL,
        headers={"Accept": "application/json", "User-Agent": "u2b22-pomodoro/0.1"},
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            final_url = response.geturl()
            content_type = response.headers.get_content_type()
            raw = response.read(REMOTE_CLIENT_MAX_BYTES + 1)
    except urllib.error.HTTPError as error:
        raise SyncError(
            "network", f"Shared OAuth client returned HTTP {error.code}"
        ) from error
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        reason = getattr(error, "reason", error)
        raise SyncError(
            "network", f"Shared OAuth client is unreachable: {reason}"
        ) from error
    if final_url != REMOTE_CLIENT_URL:
        raise SyncError("network", "Shared OAuth client redirected unexpectedly")
    if content_type != "application/json":
        raise SyncError("network", "Shared OAuth client is not JSON")
    if len(raw) > REMOTE_CLIENT_MAX_BYTES:
        raise SyncError("network", "Shared OAuth client is unexpectedly large")
    try:
        payload = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SyncError("network", "Shared OAuth client is not valid JSON") from error
    _, secret = parse_client(payload, "shared OAuth client")
    if not secret:
        raise SyncError("network", "Shared OAuth client has no client_secret")
    return payload


def _write_client_cache(payload: Any) -> None:
    directory = CLIENT_CACHE_PATH.parent
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(directory, 0o700)
    descriptor, temporary = tempfile.mkstemp(
        prefix=f".{CLIENT_CACHE_PATH.name}.", suffix=".tmp", dir=directory
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            os.fchmod(handle.fileno(), 0o600)
            json.dump(payload, handle, separators=(",", ":"))
        os.replace(temporary, CLIENT_CACHE_PATH)
    finally:
        Path(temporary).unlink(missing_ok=True)


def _cache_age() -> float | None:
    try:
        return time_module.time() - CLIENT_CACHE_PATH.lstat().st_mtime
    except OSError:
        return None


def load_client() -> tuple[str, str]:
    if CONFIG_PATH.exists() or CONFIG_PATH.is_symlink():
        return parse_client(_read_private_json(CONFIG_PATH), str(CONFIG_PATH))
    age = _cache_age()
    if age is not None and 0 <= age < CLIENT_CACHE_MAX_AGE:
        try:
            return parse_client(
                _read_private_json(CLIENT_CACHE_PATH), "cached OAuth client"
            )
        except SyncError:
            pass
    try:
        payload = _fetch_remote_client()
    except SyncError:
        # Google sign-in still works with an older client copy; only fail when
        # there is no copy at all.
        if age is None:
            raise
        return parse_client(
            _read_private_json(CLIENT_CACHE_PATH), "cached OAuth client"
        )
    try:
        _write_client_cache(payload)
    except OSError:
        pass
    return parse_client(payload, "shared OAuth client")


# ---------------------------------------------------------------- refresh token


def _secret_tool(
    args: list[str], *, stdin: str | None = None
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            ["secret-tool", *args],
            input=stdin,
            text=True,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError as error:
        raise SyncError("secret", "secret-tool is not installed") from error
    except OSError as error:
        raise SyncError("secret", f"cannot run secret-tool: {error}") from error


def load_refresh_token() -> str:
    result = _secret_tool(
        ["lookup", "service", SECRET_SERVICE, "account", SECRET_ACCOUNT]
    )
    token = result.stdout.strip()
    if result.returncode != 0 or not token:
        raise SyncError("connect", "Not connected to Google")
    return token


def save_refresh_token(token: str) -> None:
    result = _secret_tool(
        [
            "store",
            "--label",
            "u2b22.pomodoro Google refresh token",
            "service",
            SECRET_SERVICE,
            "account",
            SECRET_ACCOUNT,
        ],
        stdin=token,
    )
    if result.returncode != 0:
        raise SyncError("secret", "Secret Service refused to store the Google token")


# ---------------------------------------------------------------- HTTP


def _json_request(request: urllib.request.Request, name: str) -> dict[str, Any]:
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        try:
            details = json.loads(error.read())
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            details = {}
        if not isinstance(details, dict):
            details = {}
        reason = details.get("error")
        if isinstance(reason, dict):
            reason = reason.get("message")
        if reason in ("invalid_grant", "unauthorized_client"):
            raise SyncError(
                "connect", "Google access expired or was revoked. Connect again."
            ) from error
        suffix = f": {reason}" if isinstance(reason, str) and reason else ""
        raise SyncError(
            "network", f"{name} returned HTTP {error.code}{suffix}"
        ) from error
    except urllib.error.URLError as error:
        raise SyncError("network", f"{name} is unreachable: {error.reason}") from error
    except (TimeoutError, OSError) as error:
        raise SyncError("network", f"{name} request failed: {error}") from error
    try:
        data = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SyncError("network", f"{name} returned invalid JSON") from error
    if not isinstance(data, dict):
        raise SyncError("network", f"{name} returned an unexpected response")
    return data


def _token_request(values: dict[str, str]) -> dict[str, Any]:
    request = urllib.request.Request(
        TOKEN_ENDPOINT,
        data=urllib.parse.urlencode(values).encode("ascii"),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    return _json_request(request, "Google token endpoint")


def access_token(client_id: str, client_secret: str, refresh_token: str) -> str:
    values = {
        "client_id": client_id,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token",
    }
    if client_secret:
        values["client_secret"] = client_secret
    token = _token_request(values).get("access_token")
    if not isinstance(token, str) or not token:
        raise SyncError("network", "Google did not return an access token")
    return token


def _api_get(token: str, path: str, params: dict[str, str]) -> list[dict[str, Any]]:
    """GET a paginated Calendar API collection and return all its items."""
    items: list[dict[str, Any]] = []
    page_token = ""
    seen: set[str] = set()
    while True:
        query = dict(params)
        if page_token:
            query["pageToken"] = page_token
        request = urllib.request.Request(
            f"{CALENDAR_ENDPOINT}{path}?{urllib.parse.urlencode(query)}",
            headers={"Authorization": "Bearer " + token},
        )
        data = _json_request(request, "Google Calendar API")
        page = data.get("items", [])
        if not isinstance(page, list):
            raise SyncError("network", "Google Calendar API returned no item list")
        items.extend(item for item in page if isinstance(item, dict))
        page_token = data.get("nextPageToken")
        if not page_token:
            return items
        if not isinstance(page_token, str) or page_token in seen:
            raise SyncError("network", "Google Calendar API pagination is broken")
        seen.add(page_token)


# ---------------------------------------------------------------- sync


def find_calendar(calendars: list[dict[str, Any]], name: str) -> dict[str, Any]:
    matches = [
        calendar
        for calendar in calendars
        if name in (calendar.get("summaryOverride"), calendar.get("summary"))
        and isinstance(calendar.get("id"), str)
    ]
    if not matches:
        raise SyncError("calendar", f"No calendar named “{name}”")
    if len(matches) > 1:
        raise SyncError("calendar", f"More than one calendar is named “{name}”")
    return matches[0]


def local_day(today: date) -> tuple[datetime, datetime]:
    """Local midnight to the next local midnight, DST-aware."""
    start = datetime.combine(today, time.min).astimezone()
    end = datetime.combine(today + timedelta(days=1), time.min).astimezone()
    return start, end


def _epoch_ms(value: datetime) -> int:
    return int(value.timestamp() * 1000)


class _PlainText(HTMLParser):
    """Flatten the HTML Google Calendar stores in descriptions."""

    BREAKS = {"br", "p", "div", "ul", "ol", "tr", "h1", "h2", "h3", "h4"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "li":
            self.parts.append("\n• ")
        elif tag in self.BREAKS:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in self.BREAKS:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def plain_description(value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        return ""
    parser = _PlainText()
    parser.feed(value)
    parser.close()
    lines = [" ".join(line.split()) for line in "".join(parser.parts).splitlines()]
    text = re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()
    return text


def timed_events(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Keep timed, non-cancelled events; all-day events are not pomodoros."""
    events = []
    for item in items:
        if item.get("status") == "cancelled":
            continue
        start = item.get("start") or {}
        end = item.get("end") or {}
        if not isinstance(start, dict) or not isinstance(end, dict):
            continue
        start_value = start.get("dateTime")
        end_value = end.get("dateTime")
        if not isinstance(start_value, str) or not isinstance(end_value, str):
            continue
        try:
            start_at = datetime.fromisoformat(start_value.replace("Z", "+00:00"))
            end_at = datetime.fromisoformat(end_value.replace("Z", "+00:00"))
        except ValueError:
            continue
        if end_at <= start_at:
            continue
        title = item.get("summary")
        events.append(
            {
                "id": str(item.get("id", "")),
                "title": title if isinstance(title, str) and title else "(untitled)",
                "description": plain_description(item.get("description")),
                "startMs": _epoch_ms(start_at),
                "endMs": _epoch_ms(end_at),
            }
        )
    events.sort(key=lambda event: (event["startMs"], event["endMs"]))
    return events


def sync(calendar_name: str) -> dict[str, Any]:
    client_id, client_secret = load_client()
    token = access_token(client_id, client_secret, load_refresh_token())
    calendars = _api_get(
        token, "/users/me/calendarList", {"maxResults": "250", "showHidden": "true"}
    )
    calendar = find_calendar(calendars, calendar_name)
    day_start, day_end = local_day(date.today())
    items = _api_get(
        token,
        "/calendars/" + urllib.parse.quote(calendar["id"], safe="") + "/events",
        {
            "singleEvents": "true",
            "showDeleted": "false",
            "orderBy": "startTime",
            "maxResults": "2500",
            "timeMin": day_start.isoformat(),
            "timeMax": day_end.isoformat(),
        },
    )
    color = calendar.get("backgroundColor")
    return {
        "ok": True,
        "calendar": {
            "name": calendar_name,
            "color": color if isinstance(color, str) else "",
        },
        "dayStart": _epoch_ms(day_start),
        "dayEnd": _epoch_ms(day_end),
        "fetchedAt": _epoch_ms(datetime.now().astimezone()),
        "events": timed_events(items),
    }


# ---------------------------------------------------------------- connect


class _CallbackHandler(BaseHTTPRequestHandler):
    def __init__(self, results: queue.Queue[dict[str, str]], *args: Any, **kwargs: Any):
        self._results = results
        super().__init__(*args, **kwargs)

    def do_GET(self) -> None:
        parsed = urllib.parse.urlsplit(self.path)
        if parsed.path != CALLBACK_PATH:
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        values = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
        code = values.get("code", [""])[0]
        state = values.get("state", [""])[0]
        if code and state:
            result = {"code": code, "state": state}
        else:
            result = {
                "error": values.get("error", ["missing authorization response"])[0]
            }
        try:
            self._results.put_nowait(result)
        except queue.Full:
            pass
        body = b"Pomodoro is connected to Google Calendar. You can close this tab."
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: Any) -> None:
        return


def connect() -> dict[str, Any]:
    client_id, client_secret = load_client()
    state = secrets.token_urlsafe(32)
    verifier = secrets.token_urlsafe(64)
    challenge = (
        base64.urlsafe_b64encode(hashlib.sha256(verifier.encode("ascii")).digest())
        .rstrip(b"=")
        .decode("ascii")
    )
    results: queue.Queue[dict[str, str]] = queue.Queue(maxsize=1)

    def handler(*args: Any, **kwargs: Any) -> _CallbackHandler:
        return _CallbackHandler(results, *args, **kwargs)

    server = HTTPServer(("127.0.0.1", 0), handler)
    redirect_uri = f"http://127.0.0.1:{server.server_port}{CALLBACK_PATH}"
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        url = (
            AUTH_ENDPOINT
            + "?"
            + urllib.parse.urlencode(
                {
                    "client_id": client_id,
                    "redirect_uri": redirect_uri,
                    "response_type": "code",
                    "scope": " ".join(SCOPES),
                    "access_type": "offline",
                    "prompt": "consent",
                    "state": state,
                    "code_challenge": challenge,
                    "code_challenge_method": "S256",
                }
            )
        )
        if not webbrowser.open(url):
            raise SyncError("connect", "Could not open a browser for Google sign-in")
        try:
            result = results.get(timeout=300)
        except queue.Empty as error:
            raise SyncError(
                "connect", "Timed out waiting for Google sign-in"
            ) from error
        if "error" in result:
            raise SyncError("connect", f"Google sign-in failed: {result['error']}")
        if result.get("state") != state:
            raise SyncError("connect", "Google sign-in state did not match")
        values = {
            "client_id": client_id,
            "code": result["code"],
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri,
        }
        if client_secret:
            values["client_secret"] = client_secret
        refresh_token = _token_request(values).get("refresh_token")
        if not isinstance(refresh_token, str) or not refresh_token:
            raise SyncError("connect", "Google did not return a refresh token")
        save_refresh_token(refresh_token)
        return {"ok": True, "message": "Connected to Google Calendar"}
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


# ---------------------------------------------------------------- entry point


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    sync_parser = commands.add_parser("sync", help="print today's events as JSON")
    sync_parser.add_argument("--calendar", required=True, help="calendar display name")
    commands.add_parser("connect", help="sign in to Google in the browser")
    args = parser.parse_args(argv)

    try:
        payload = sync(args.calendar) if args.command == "sync" else connect()
    except SyncError as error:
        payload = {"ok": False, "kind": error.kind, "error": str(error)}
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    return 0 if payload["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
