---
name: one-password
description: "1Password CLI/op: desktop sign-in, account choice, targeted secret read/store/inject. tmux-only op commands."
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
4. REQUIRED: create exactly one persistent named tmux session for the whole secret task.
5. Sign in / authorize once inside that same session: `op signin` (expect one app prompt).
6. Verify access inside that same session: `op whoami` (must succeed before any secret read).
7. If multiple accounts: use `--account` or `OP_ACCOUNT`.
8. If a command fails, reuse the same tmux session with `tmux send-keys`; do not start a second session just to retry.

## Default Account

- Default account for personal/work secrets is `my.1password.com`.
- Do not silently use `my.1password.eu` / Titan unless explicitly asked.
- Pass `--account my.1password.com` on every `op` command when storing or reading secrets. Do not rely on ambient account selection.
- `op account list` is metadata-only, but still must run inside tmux. Use it to confirm account names when routing is unclear.
- `op signin --account my.1password.com` can return status 0 with no useful output and still not make a later shell signed in. Prefer doing sign-in, create/edit/get, and verification in the same tmux shell.

## Service account tokens

- 1Password service accounts are non-interactive tokens for a specific vault/scope, useful for automation without unlocking the desktop app.
- The current service-account env var is `MOLTY_OP_SERVICE_ACCOUNT_TOKEN` in `~/.profile`; use it only for known items in the restricted `Molty` vault.
- Check `~/.profile` first for service-account tokens before asking the user to unlock the 1Password desktop app.
- Export it only for the single command that needs it: `OP_SERVICE_ACCOUNT_TOKEN="$MOLTY_OP_SERVICE_ACCOUNT_TOKEN" op item get "<known item>" --vault Molty ...`.
- Service-account `op` reads require an explicit vault query; omitting `--vault Molty` fails even when the token is valid.
- Keep the tmux rule: every `op` command, including service-account reads, still runs inside one named tmux session.
- Do not enumerate vaults/items with service accounts. If the known item or field is not accessible, stop and ask the user instead of probing.
- Print presence/shape only, never token or secret values.

## Required Persistent Tmux Session

The shell tool uses a fresh TTY per command. To avoid repeated 1Password prompts, run `op` inside one dedicated tmux session and keep using that same session until the whole secret task is done.

Example:

```bash
SOCKET_DIR="${CLAWDBOT_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/clawdbot-tmux-sockets}"
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/clawdbot-op.sock"
SESSION="op-work"

tmux -S "$SOCKET" has-session -t "$SESSION" 2>/dev/null ||
  tmux -S "$SOCKET" new -d -s "$SESSION" -n shell
tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -- "op signin --account my.1password.com" Enter
tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -- "op whoami" Enter
tmux -S "$SOCKET" capture-pane -p -J -t "$SESSION":0.0 -S -200
```

Do not create a new tmux session after a quoting, item-name, or npm command failure. Send a corrected command into the existing session.

## Known npm Auth Item

- npm auth item: `npmjs`.
- Use exactly one persistent tmux session for npm publish/reservation work.
- Read `npmjs` once, keep the secret in an in-memory shell variable, write a temporary npmrc, run all `npm whoami` / `npm publish` commands, delete npmrc, unset the variable.
- If the token field is ambiguous or `npm whoami` fails, stop and ask for the exact field label. Do not probe more items or start another tmux session.

## Known working secret-write pattern

Use the persistent tmux session, read the secret from the clipboard without printing it, optionally validate an expected token prefix, and write to the default account explicitly. The `op` category string is human-readable and case-sensitive in this CLI build; use `"API Credential"`, not `api_credential`.

```bash
tmux new-session -d -s op-store-secret 'bash -lc '\''set -euo pipefail
set +x
ACCOUNT="my.1password.com"
ITEM_TITLE="Service API Tokens"
FIELD_NAME="api_token"
EXPECTED_PREFIX=""
NOTES="Created via tmux-safe op workflow"
TOKEN="$(pbpaste)"
if [ -n "$EXPECTED_PREFIX" ]; then
  case "$TOKEN" in "$EXPECTED_PREFIX"*) ;; *) echo "clipboard value does not match expected prefix" >&2; exit 2;; esac
fi
op item create --account "$ACCOUNT" --category "API Credential" --title "$ITEM_TITLE" "$FIELD_NAME[password]=$TOKEN" "notesPlain=$NOTES" >/dev/null
op item get "$ITEM_TITLE" --account "$ACCOUNT" --fields "label=$FIELD_NAME" >/dev/null
echo "stored and verified secret field without printing it"
sleep 30
'\'''
```

For a second secret on the same item:

```bash
tmux new-session -d -s op-edit-secret 'bash -lc '\''set -euo pipefail
set +x
ACCOUNT="my.1password.com"
ITEM_TITLE="Service API Tokens"
FIELD_NAME="app_token"
EXPECTED_PREFIX=""
TOKEN="$(pbpaste)"
if [ -n "$EXPECTED_PREFIX" ]; then
  case "$TOKEN" in "$EXPECTED_PREFIX"*) ;; *) echo "clipboard value does not match expected prefix" >&2; exit 2;; esac
fi
op item edit "$ITEM_TITLE" --account "$ACCOUNT" "$FIELD_NAME[password]=$TOKEN" >/dev/null
op item get "$ITEM_TITLE" --account "$ACCOUNT" --fields "label=$FIELD_NAME" >/dev/null
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
