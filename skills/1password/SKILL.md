---
name: 1password
description: Set up and use 1Password CLI (op, one-password). Use when installing the CLI, enabling desktop app integration, signing in, selecting Peter's multi-account setup, or storing/reading/injecting/running secrets via op. Always use tmux for op commands.
metadata: {"clawdbot":{"emoji":"🔐","requires":{"bins":["op"]},"install":[{"id":"brew","kind":"brew","formula":"1password-cli","bins":["op"],"label":"Install 1Password CLI (brew)"}]}}
---

# 1Password CLI

Follow the official CLI get-started steps. Don't guess install commands.

## References

- Official docs: https://developer.1password.com/docs/cli/get-started/
- `references/get-started.md` (install + app integration + sign-in flow)
- `references/cli-examples.md` (real `op` examples, including safe item create/edit patterns)

## Workflow

1. Check OS + shell.
2. Verify CLI present inside tmux: `op --version`.
3. Confirm desktop app integration is enabled (per get-started) and the app is unlocked.
4. REQUIRED: create a fresh tmux session for all `op` commands (no direct `op` calls outside tmux).
5. Sign in / authorize inside tmux: `op signin` (expect app prompt).
6. Verify access inside tmux: `op whoami` (must succeed before any secret read).
7. If multiple accounts: use `--account` or `OP_ACCOUNT`.

## Peter account defaults

- Peter's default account for personal/work secrets is `my.1password.com` ("Peter Steinberger's Clan").
- Do not silently use `my.1password.eu` / Titan unless Peter asks for it.
- Pass `--account my.1password.com` on every `op` command when storing or reading Peter's secrets. Do not rely on ambient account selection.
- `op account list` is metadata-only, but still must run inside tmux. Use it to confirm account names when routing is unclear.
- `op signin --account my.1password.com` can return status 0 with no useful output and still not make a later shell signed in. Prefer doing sign-in, create/edit/get, and verification in the same tmux shell.

## REQUIRED tmux session (T-Max)

The shell tool uses a fresh TTY per command. To avoid re-prompts and failures, always run `op` inside a dedicated tmux session with a fresh socket/session name.

Example (see `tmux` skill for socket conventions, do not reuse old session names):

```bash
SOCKET_DIR="${CLAWDBOT_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/clawdbot-tmux-sockets}"
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/clawdbot-op.sock"
SESSION="op-auth-$(date +%Y%m%d-%H%M%S)"

tmux -S "$SOCKET" new -d -s "$SESSION" -n shell
tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -- "op signin --account my.1password.com" Enter
tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -- "op whoami" Enter
tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -- "op vault list" Enter
tmux -S "$SOCKET" capture-pane -p -J -t "$SESSION":0.0 -S -200
tmux -S "$SOCKET" kill-session -t "$SESSION"
```

## Known working secret-write pattern

Use a fresh tmux session, read the secret from the clipboard without printing it, validate the expected token prefix, and write to Peter's account explicitly. The `op` category string is human-readable and case-sensitive in this CLI build; use `"API Credential"`, not `api_credential`.

```bash
tmux new-session -d -s op-store-secret 'bash -lc '\''set -euo pipefail
set +x
TOKEN="$(pbpaste)"
case "$TOKEN" in xoxb-*) ;; *) echo "clipboard does not contain expected Slack bot token" >&2; exit 2;; esac
op item create --account my.1password.com --category "API Credential" --title "OpenClaw Foundation Slack Clawd" "bot_token[password]=$TOKEN" "notesPlain=Slack tokens for OpenClaw Foundation Clawd" >/dev/null
op item get "OpenClaw Foundation Slack Clawd" --account my.1password.com --fields label=bot_token >/dev/null
echo "stored and verified secret field without printing it"
sleep 30
'\'''
```

For a second secret on the same item:

```bash
tmux new-session -d -s op-edit-secret 'bash -lc '\''set -euo pipefail
set +x
TOKEN="$(pbpaste)"
case "$TOKEN" in xapp-*) ;; *) echo "clipboard does not contain expected Slack app token" >&2; exit 2;; esac
op item edit "OpenClaw Foundation Slack Clawd" --account my.1password.com "app_token[password]=$TOKEN" >/dev/null
op item get "OpenClaw Foundation Slack Clawd" --account my.1password.com --fields label=app_token >/dev/null
echo "stored and verified secret field without printing it"
sleep 30
'\'''
```

## Redacted debugging

Keep the whole pipeline inside tmux. Inspect status and output length, never secret values.

```bash
tmux new-session -d -s op-debug 'bash -lc '\''set -euo pipefail
set +x
SIGNIN_OUTPUT="$(op signin --account my.1password.com 2>&1 || true)"
echo "signin output bytes: ${#SIGNIN_OUTPUT}"
op account list 2>&1 | sed -E "s/(xox[baprs]-)[A-Za-z0-9-]+/\\1REDACTED/g; s/(xapp-)[A-Za-z0-9-]+/\\1REDACTED/g"
sleep 30
'\'''
```

## Guardrails

- Never paste secrets into logs, chat, or code.
- Prefer `op run` / `op inject` over writing secrets to disk.
- If sign-in without app integration is needed, use `op account add`.
- If a command returns "account is not signed in", re-run `op signin` inside tmux and authorize in the app.
- Do not run `op` outside tmux; stop and ask if tmux is unavailable.
