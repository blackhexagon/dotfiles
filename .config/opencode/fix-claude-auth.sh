#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI is not on PATH" >&2
  exit 1
fi

echo "Current Claude auth status:"
claude auth status || true

echo
echo "Logging out stale Claude auth..."
claude auth logout || true

echo
echo "Starting Claude login. Complete the browser/device flow when prompted."
claude auth login

echo
echo "Verifying Claude inference auth..."
claude -p . --model haiku >/dev/null

echo
echo "Checking Claude credential file without printing tokens..."
node <<'NODE'
const fs = require("fs");
const path = `${process.env.HOME}/.claude/.credentials.json`;
const raw = fs.readFileSync(path, "utf8");
const parsed = JSON.parse(raw);
const creds = parsed.claudeAiOauth ?? parsed;

const problems = [];
if (typeof creds.accessToken !== "string" || creds.accessToken.length === 0) problems.push("missing accessToken");
if (typeof creds.refreshToken !== "string" || creds.refreshToken.length === 0) problems.push("missing refreshToken");
if (typeof creds.expiresAt !== "number") problems.push("missing numeric expiresAt");
if (typeof creds.expiresAt === "number" && creds.expiresAt <= Date.now() + 60_000) problems.push("credentials expired or near expiry");

if (problems.length > 0) {
  console.error(`Claude credentials still invalid: ${problems.join(", ")}`);
  process.exit(1);
}

console.log(`Claude credentials look usable; expires at ${new Date(creds.expiresAt).toISOString()}`);
NODE

echo
echo "Removing stale opencode Anthropic OAuth cache while preserving other providers..."
node <<'NODE'
const fs = require("fs");
const path = `${process.env.HOME}/.local/share/opencode/auth.json`;

if (!fs.existsSync(path)) {
  process.exit(0);
}

const raw = fs.readFileSync(path, "utf8").trim();
if (!raw) {
  process.exit(0);
}

const auth = JSON.parse(raw);
delete auth.anthropic;
fs.writeFileSync(path, `${JSON.stringify(auth, null, 2)}\n`, { mode: 0o600 });
fs.chmodSync(path, 0o600);
NODE

echo
echo "Claude auth is refreshed. Quit and restart opencode so opencode-claude-auth reloads credentials."
