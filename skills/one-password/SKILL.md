---
name: one-password
description: "1Password/op: service-account first, sign-in fallback, targeted secret read/store/inject; tmux only."
metadata: {"clawdbot":{"emoji":"🔐","requires":{"bins":["op","tmux"]},"install":[{"id":"brew","kind":"brew","formula":"1password-cli","bins":["op"],"label":"Install 1Password CLI (brew)"}]}}
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
3. REQUIRED: create exactly one persistent named tmux session for the whole secret task.
4. Try scoped service-account access first when a matching token/workflow exists; no dialogs.
5. If service-account access is missing or lacks the exact item/field needed, stop and ask before desktop-app sign-in.
6. Desktop fallback: confirm app integration/unlock, then `op signin` once inside the same session.
7. Verify chosen access path inside that same session: `op whoami`.
8. If multiple accounts: use `--account` or `OP_ACCOUNT`.
9. If a command fails, reuse the same tmux session with `tmux send-keys`; do not start a second session just to retry.

## Default Account

- Default account for personal/work secrets is `my.1password.com`.
- Do not silently use `my.1password.eu` / Titan unless explicitly asked.
- Pass `--account my.1password.com` on every `op` command when storing or reading secrets. Do not rely on ambient account selection.
- `op account list` is metadata-only, but still must run inside tmux. Use it to confirm account names when routing is unclear.
- `op signin --account my.1password.com` can return status 0 with no useful output and still not make a later shell signed in. Prefer doing sign-in, create/edit/get, and verification in the same tmux shell.

## Service account tokens

- Prefer service-account tokens before any interactive 1Password flow. User dialogs are fallback only.
- 1Password service accounts are non-interactive tokens for a specific vault/scope, useful for automation without unlocking the desktop app.
- Peter's default service-account token is exported from `~/.profile` as `OP_SERVICE_ACCOUNT_TOKEN` in a Codex-managed block. It is scoped to the restricted `Molty` vault.
- Older shells may expose the same value as `MOLTY_OP_SERVICE_ACCOUNT_TOKEN`; treat that as a fallback alias for known `Molty` vault items.
- If the token is not already exported, not applicable, or cannot read the exact known item/field required, ask the user before using the desktop-app 1Password flow below.
- Export/pass it only for the single command that needs it: `OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" op item get "<known item>" --vault Molty ...`.
- Service-account `op` reads require an explicit vault query; omitting `--vault Molty` fails even when the token is valid.
- Keep the tmux rule: every `op` command, including service-account reads, still runs inside one named tmux session.
- Do not enumerate vaults/items with service accounts. If the known item or field is not accessible, stop and ask the user instead of probing or triggering app dialogs.
- Print presence/shape only, never token or secret values.

## Required Persistent Tmux Session

The shell tool uses a fresh TTY per command. Run `op` inside one dedicated tmux session and keep using that same session until the whole secret task is done. Service-account commands still run here, but must not trigger app prompts.

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

Do not create a new tmux session after a quoting, item-name, or command failure. Send a corrected command into the existing session.

## Service-Specific Workflows

- Keep service-specific auth details in the owning skill.
- For npm registry/package work, use `$npm`; it documents the `npmjs` item, username/password/TOTP flow, and package reservation helper.
- This skill owns only the generic 1Password rules: tmux-only `op`, targeted reads, one persistent session, no broad enumeration, no secret output.

## Known working secret-write pattern

Use the persistent tmux session. Write the exact secret task to a temp script, then send that script into `op-work`; do not create a second tmux session for retries.

```bash
SOCKET_DIR="${CLAWDBOT_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/clawdbot-tmux-sockets}"
SOCKET="$SOCKET_DIR/clawdbot-op.sock"
SESSION="op-work"
tmux -S "$SOCKET" has-session -t "$SESSION" 2>/dev/null ||
  tmux -S "$SOCKET" new -d -s "$SESSION" -n shell

cat > /tmp/op-store-secret.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
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
SCRIPT
chmod 700 /tmp/op-store-secret.sh
tmux -S "$SOCKET" send-keys -t "$SESSION" -- "bash /tmp/op-store-secret.sh; rm -f /tmp/op-store-secret.sh" C-m
```

The `op` category string is human-readable and case-sensitive in this CLI build; use `"API Credential"`, not `api_credential`.

## Redacted debugging

Keep the whole pipeline inside the same tmux session. Inspect status and output length, never secret values.

```bash
cat > /tmp/op-debug.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
set +x
SIGNIN_OUTPUT="$(op signin --account my.1password.com 2>&1 || true)"
echo "signin output bytes: ${#SIGNIN_OUTPUT}"
op account list 2>&1 | sed -E "s/(xox[baprs]-)[A-Za-z0-9-]+/\\1REDACTED/g; s/(xapp-)[A-Za-z0-9-]+/\\1REDACTED/g"
SCRIPT
chmod 700 /tmp/op-debug.sh
tmux -S "$SOCKET" send-keys -t "$SESSION" -- "bash /tmp/op-debug.sh; rm -f /tmp/op-debug.sh" C-m
```

## Guardrails

- Never paste secrets into logs, chat, or code.
- Prefer `op run` / `op inject` over writing secrets to disk.
- If sign-in without app integration is needed, use `op account add`.
- If a command returns "account is not signed in", re-run `op signin` inside tmux and authorize in the app.
- Do not run `op` outside tmux; stop and ask if tmux is unavailable.
