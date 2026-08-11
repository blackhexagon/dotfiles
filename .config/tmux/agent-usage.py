#!/usr/bin/env python3

import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


CACHE_TTL = 300
RETRY_DELAY = 60
CACHE_PATH = (
    Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
    / "tmux-agent-usage.json"
)


def read_json(path):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError as exc:
        raise RuntimeError(f"file not found: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"cannot read {path}: {exc}") from exc


def fetch_claude():
    credentials_path = Path.home() / ".claude" / ".credentials.json"
    oauth = read_json(credentials_path).get("claudeAiOauth") or {}
    access_token = oauth.get("accessToken")
    if not access_token:
        raise RuntimeError(f"missing Claude access token in {credentials_path}")

    body = json.dumps(
        {
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [{"role": "user", "content": "0"}],
        }
    ).encode()
    request = Request(
        "https://api.anthropic.com/v1/messages",
        data=body,
        headers={
            "Authorization": f"Bearer {access_token}",
            "anthropic-beta": "oauth-2025-04-20",
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "tmux-agent-usage/1.0",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=15) as response:
            headers = {key.lower(): value for key, value in response.getheaders()}
    except HTTPError as exc:
        headers = {key.lower(): value for key, value in exc.headers.items()}
        if not any(key.startswith("anthropic-ratelimit-unified") for key in headers):
            raise RuntimeError(f"Claude API returned HTTP {exc.code}") from exc
    except URLError as exc:
        raise RuntimeError(f"Claude request failed: {exc.reason}") from exc

    representative = headers.get(
        "anthropic-ratelimit-unified-representative-claim", "five_hour"
    )
    window = "5h" if representative == "five_hour" else "7d"
    utilization = headers.get(f"anthropic-ratelimit-unified-{window}-utilization")
    reset_at = headers.get(f"anthropic-ratelimit-unified-{window}-reset")
    if utilization is None or reset_at is None:
        raise RuntimeError("Claude response is missing usage headers")

    try:
        percent = max(0, min(100, 100 - round(float(utilization) * 100)))
        return {"percent": percent, "reset_at": int(reset_at)}
    except ValueError as exc:
        raise RuntimeError("Claude response contains invalid usage headers") from exc


def fetch_codex():
    auth_path = Path.home() / ".codex" / "auth.json"
    tokens = read_json(auth_path).get("tokens") or {}
    access_token = tokens.get("access_token")
    account_id = tokens.get("account_id")
    if not access_token or not account_id:
        raise RuntimeError(f"missing Codex authentication in {auth_path}")

    request = Request(
        "https://chatgpt.com/backend-api/wham/usage",
        headers={
            "Authorization": f"Bearer {access_token}",
            "ChatGPT-Account-Id": account_id,
            "Accept": "application/json",
            "User-Agent": "tmux-agent-usage/1.0",
        },
        method="GET",
    )

    try:
        with urlopen(request, timeout=15) as response:
            payload = json.loads(response.read().decode())
    except HTTPError as exc:
        raise RuntimeError(f"Codex API returned HTTP {exc.code}") from exc
    except URLError as exc:
        raise RuntimeError(f"Codex request failed: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError("Codex response contains invalid JSON") from exc

    window = (payload.get("rate_limit") or {}).get("primary_window") or {}
    used_percent = window.get("used_percent")
    reset_at = window.get("reset_at")
    if used_percent is None or reset_at is None:
        raise RuntimeError("Codex response is missing primary-window usage")

    try:
        percent = max(0, min(100, 100 - round(float(used_percent))))
        return {"percent": percent, "reset_at": int(reset_at)}
    except (TypeError, ValueError) as exc:
        raise RuntimeError("Codex response contains invalid usage values") from exc


def read_cache():
    try:
        payload = json.loads(CACHE_PATH.read_text())
        return payload if isinstance(payload, dict) else {}
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        return {}


def write_cache(cache):
    try:
        CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        temporary_path = CACHE_PATH.with_suffix(".tmp")
        temporary_path.write_text(json.dumps(cache))
        temporary_path.chmod(0o600)
        temporary_path.replace(CACHE_PATH)
    except OSError:
        pass


def has_usage(entry):
    return (
        isinstance(entry, dict)
        and isinstance(entry.get("percent"), int)
        and isinstance(entry.get("reset_at"), int)
    )


def format_duration(seconds):
    seconds = max(0, seconds)
    if seconds >= 86400:
        return f"{(seconds + 43200) // 86400}d"

    hours, remainder = divmod(seconds, 3600)
    minutes = remainder // 60

    if hours:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def load_usage():
    now = int(time.time())
    cache = read_cache()
    fetchers = {"claude": fetch_claude, "codex": fetch_codex}
    pending = {}
    errors = []

    for agent, fetcher in fetchers.items():
        entry = cache.get(agent) or {}
        fresh = has_usage(entry) and now - entry.get("fetched_at", 0) < CACHE_TTL
        retry_later = entry.get("retry_at", 0) > now
        if not fresh and not retry_later:
            pending[agent] = fetcher

    if pending:
        with ThreadPoolExecutor(max_workers=len(pending)) as executor:
            futures = {
                executor.submit(fetcher): agent for agent, fetcher in pending.items()
            }
            for future in as_completed(futures):
                agent = futures[future]
                try:
                    cache[agent] = {**future.result(), "fetched_at": now}
                except Exception as exc:
                    entry = cache.get(agent) or {}
                    entry["retry_at"] = now + RETRY_DELAY
                    cache[agent] = entry
                    errors.append(f"{agent}: {exc}")
        write_cache(cache)

    return cache, errors


def format_agent(entry, icon, color):
    if has_usage(entry):
        seconds = max(0, entry["reset_at"] - int(time.time()))
        usage = f"{entry['percent']}% {format_duration(seconds)}"
    else:
        usage = "--% --:--"
    return f"#[fg={color},bold]{icon} {usage}#[default]"


def main():
    cache, errors = load_usage()
    claude = format_agent(cache.get("claude"), "✻", "#9a3f00")
    codex = format_agent(cache.get("codex"), ">_", "blue")
    print(f"{claude} | {codex}")
    if errors:
        print("; ".join(errors), file=sys.stderr)


if __name__ == "__main__":
    main()
