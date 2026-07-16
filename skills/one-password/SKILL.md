---
name: one-password
description: "1Password/op: service-account first, targeted secret read/store/inject, tmux."
metadata: {"clawdbot":{"emoji":"🔐","requires":{"bins":["op","tmux"]}}}
---

# 1Password CLI

## Install (stable path only — never brew)

`op` lives at `~/bin/op` on all of Peter's Macs, with a compat symlink `/opt/homebrew/bin/op -> ~/bin/op`. Do NOT install/upgrade via the Homebrew cask: its versioned Caskroom path gives `op` a new macOS TCC identity on every upgrade, which re-fires the App Data Protection dialog at Peter. To update: download the official signed pkg from https://app-updates.agilebits.com/product_history/CLI2, `pkgutil --check-signature` (AgileBits 2BUA8C4S2C) + `pkgutil --expand-full`, then `install -m 755 <payload>/op ~/bin/op`. Same path forever = TCC grant persists.

Follow the official CLI get-started steps for anything else. Don't guess install commands.

## References

- Official docs: https://developer.1password.com/docs/cli/get-started/
- `references/get-started.md` (install + app integration + sign-in flow)
- `references/cli-examples.md` (real `op` examples, including safe item create/edit patterns)

## Access paths (strict order)

**1. Service account — default, zero prompts.** `OP_SERVICE_ACCOUNT_TOKEN` is exported from `~/.profile` (Codex-managed block), scoped to the `Molty` vault (read+write). Non-interactive; never touches the desktop app.

- Pass the token per command: `OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" op item get "<item>" --vault Molty ...`.
- `--vault Molty` is required; omitting it fails even with a valid token.
- NEVER `op signin` and NEVER `--account` on this path. Either one routes through the desktop app and throws an Authorize prompt at Peter. `--account` + token = interactive path, always wrong.
- Older alias `MOLTY_OP_SERVICE_ACCOUNT_TOKEN` = fallback only; may be stale.
- Token missing/expired or item read fails: report the exact error and ask. Do NOT silently fall back to the desktop app.

**2. Desktop app — explicit consent only.** For items genuinely outside Molty (personal `Private` vault, `OpenClaw-Core`). No automatic fallback.

- STOP and ask in chat first: item name + why needed. Wait for yes.
- After consent: one task window in the shared `op-work` session (see below), `op signin --account my.1password.com` once, then batch every interactive read of the whole task into that same window. App authorization is per TTY (~10 min, refreshes on use) — reusing the one window means one Authorize prompt max per task. There is no app setting to disable the per-terminal prompt; window reuse is the only mitigation.
- No nameplate/sag pre-alerts. Audible page (`sag`) only if Peter approved the unlock in chat and the 1Password prompt then sits unanswered.

## Known Molty items (skip discovery)

Exact titles; go straight to the service-account read. No enumeration needed.

| Purpose | Item title | Field |
|---|---|---|
| OpenAI (OpenClaw/i18n jobs) | `AI API Key - OpenAI - OPENAI_API_KEY - OpenClaw` | `OPENAI_API_KEY` |
| OpenAI (serviceable access) | `AI API Key - OpenAI - OPENAI_API_KEY - Serviceable Access` | `OPENAI_API_KEY` |
| Anthropic (live tests) | `AI API Key - Anthropic - ANTHROPIC_API_KEY - OpenClaw Live Tests` | `ANTHROPIC_API_KEY` |
| Anthropic (clawdbot) | `AI API Key - Anthropic - ANTHROPIC_API_KEY - Clawdbot` | `ANTHROPIC_API_KEY` |
| Gemini | `AI API Key - Google Gemini - GEMINI_API_KEY - steipete-m5` | `GEMINI_API_KEY` |
| App Store Connect release | `API Key - App Store Connect - Personal - Release` | `private_key_p8`, `key_id`, `issuer_id` |
| npm release automation | `npm Registry - steipete - Release Automation` | see `$npm` |
| Cloudflare (OpenClaw services) | `OpenClaw Services Cloudflare API Token` | `credential` |
| Sparkle signing | `Nameplate Sparkle EdDSA` | `private key` |
| Octopool | `Octopool Proxy Secret`, `Octopool Admin Token (OpenClaw account)` | `credential` |
| GitHub PAT | `GitHub Personal Access Token`, `GitHub Personal Access Token Xcode 26` | `credential` |
| Crabyard deploy | `Cloudflare OpenClaw Crabyard Deploy Token` | `credential` |
| Hetzner (crabyard) | `API Key - Hetzner Cloud - OpenClaw - crabyard-ssh-gateway` | `credential` |
| Anthropic (Peekaboo) | `Anthropic API Key - Peekaboo Live Test` | `credential` |
| ClickClack deploy | `Cloudflare ClickClack deploy token`, `Cloudflare ClickClack R2 uploads` | `credential` |
| Barnacle | `GitHub Token Barnacle` | `credential` |

ClickClack/Barnacle Molty items are agent copies; canonical items live in the shared `OpenClaw` vault — on rotation update both.

Outside Molty by design (desktop path, consent first): `OpenClaw Developer ID Release Keychain` (`OpenClaw-Core` vault), npm interactive login+OTP (`Private/Npmjs`), personal SSH/signing keys. Twilio has no API credential stored anywhere — only a console login (Private); minting one needs the console.

## Workflow

1. Check OS + shell.
2. Verify CLI present inside tmux: `op --version`.
3. REQUIRED: use the shared `op-work` session; open exactly one task window in it for the whole secret task; kill that window when the task is done.
4. Known/expected Molty item → service-account read directly (path 1). Verify with `OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" op whoami >/dev/null 2>&1; echo op_rc:$?` if unsure the token works.
5. Item unknown → check the table above → vault-scoped metadata search in Molty (service account, safe) → only then the desktop consent ask (path 2).
6. If a command fails, reuse the same window with `tmux send-keys`; do not open a second window or session just to retry.
7. If multiple personal accounts in an interactive flow: `--account my.1password.com` default; never `my.1password.eu` / Titan unless explicitly asked.

## Shared Op Tmux Session — one session, one window per task

ALL `op` work on this machine — every skill, every agent, every task — shares ONE tmux server (`clawdbot-op.sock`) and ONE session (`op-work`). Never mint another socket name, tmux server, or session for secret work: every extra session fires an alert at Peter and rots into a zombie holding secrets in its shell env. Sibling skills (`$npm`, `$release-mac-app`, ad-hoc flows) use this same session and differ only in window name.

Per task: create ONE window in `op-work`, named after the task; target it by window id; kill it when the task ends.

```bash
SOCKET_DIR="${CLAWDBOT_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/clawdbot-tmux-sockets}"
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/clawdbot-op.sock"
SESSION="op-work"

# 'shell' is a permanent keeper window: never send work to it, never kill it.
tmux -S "$SOCKET" has-session -t "$SESSION" 2>/dev/null ||
  tmux -S "$SOCKET" new -d -s "$SESSION" -n shell
WIN="$(tmux -S "$SOCKET" new-window -d -t "$SESSION" -n "<task-slug>" -P -F '#{window_id}')"
tmux -S "$SOCKET" send-keys -t "$WIN" -- 'OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" op whoami >/dev/null 2>&1; echo op_rc:$?' Enter
tmux -S "$SOCKET" capture-pane -p -J -t "$WIN" -S -200
```

Service-account `op` must never sit on the pane TTY: redirect or pipe stdout+stderr (as above, or via `$(...)` in a temp script). `op` 2.35 on a TTY reads the 1Password app's group container (enforced-policies check), which fires a macOS 26 App Data Protection dialog at Peter ("op would like to access data from other apps") and blocks in `open()` until answered — even with a valid `OP_SERVICE_ACCOUNT_TOKEN`. Redirected `op` skips the interactive probe and returns in ~2s with no dialog (verified live). Only a consented desktop flow (path 2) runs `op` directly on the TTY.

- Reuse `$WIN` for every command, retry, and follow-up of the task. A quoting, item-name, or command failure means send a corrected command into the same window, never a new window or session.
- Task end (success or failure): `tmux -S "$SOCKET" kill-window -t "$WIN"` — exported secrets die with the window's shell. The keeper window keeps `op-work` alive for the next task.
- No `op signin` in bootstrap. Sign-in belongs only to a consented desktop flow (path 2), inside the task window.
- Stale task windows from crashed agents may be killed when their pane shows an idle prompt; never kill a window with a running command, and never kill `shell`.

## Service-Specific Workflows

- Keep service-specific auth details in the owning skill.
- For npm registry/package work, use `$npm`; it documents the Molty service-account item, non-interactive auth wrapper, and package reservation helper.
- This skill owns only the generic 1Password rules: tmux-only `op`, targeted reads, the shared `op-work` session with per-task windows, no broad enumeration, no secret output.

## Known working secret-write pattern

New secrets default to the `Molty` vault via the service account (no prompts). Personal-account writes only on explicit ask. Use your task window in the shared `op-work` session (bootstrap above); write the exact secret task to a temp script, send it into the window; do not create a second window or session for retries.

```bash
cat > /tmp/op-store-secret.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
set +x
VAULT="Molty"
ITEM_TITLE="Service API Tokens"
FIELD_NAME="api_token"
EXPECTED_PREFIX=""
NOTES="Created via tmux-safe op workflow"
TOKEN="$(pbpaste)"
if [ -n "$EXPECTED_PREFIX" ]; then
  case "$TOKEN" in "$EXPECTED_PREFIX"*) ;; *) echo "clipboard value does not match expected prefix" >&2; exit 2;; esac
fi
OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" op item create --vault "$VAULT" --category "API Credential" --title "$ITEM_TITLE" "$FIELD_NAME[password]=$TOKEN" "notesPlain=$NOTES" >/dev/null
OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" op item get "$ITEM_TITLE" --vault "$VAULT" --fields "label=$FIELD_NAME" >/dev/null
echo "stored and verified secret field without printing it"
SCRIPT
chmod 700 /tmp/op-store-secret.sh
tmux -S "$SOCKET" send-keys -t "$WIN" -- "bash /tmp/op-store-secret.sh; rm -f /tmp/op-store-secret.sh" C-m
```

The `op` category string is human-readable and case-sensitive in this CLI build; use `"API Credential"`, not `api_credential`.

## Exact field reads

For a known item, verify the field shape before using it live: length, expected prefix, newline count, never value. `op --field NAME` and `--fields label=NAME` can return the wrong concealed field when an item has duplicate/legacy credential fields. If shape is wrong, read the known item as JSON and extract the exact label.

```bash
cat > /tmp/op-read-field.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
set +x
ITEM_TITLE="Known API Credential Item"
FIELD_LABEL="api_token"
VAULT="Molty"
value="$(
  OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" \
    op item get "$ITEM_TITLE" --vault "$VAULT" --format json |
    FIELD_LABEL="$FIELD_LABEL" node -e 'let s=""; process.stdin.on("data",d=>s+=d); process.stdin.on("end",()=>{const item=JSON.parse(s); const f=(item.fields||[]).find(x=>x.label===process.env.FIELD_LABEL); if(!f?.value) process.exit(2); process.stdout.write(f.value);})'
)"
echo "field_len:${#value}"
case "$value" in sk-*) echo "field_prefix:sk" ;; *) echo "field_prefix:other" ;; esac
echo "field_has_newline:$(printf %s "$value" | wc -l | tr -d ' ')"
SCRIPT
chmod 700 /tmp/op-read-field.sh
tmux -S "$SOCKET" send-keys -t "$WIN" -- "bash /tmp/op-read-field.sh; rm -f /tmp/op-read-field.sh" C-m
```

Keep JSON extraction scoped to the known item and vault. Do not enumerate vaults/items to discover candidates.

## Explicit item search

Only use this when the user explicitly asks to search, gives a screenshot/listing, or the exact title guess failed. Stay vault-scoped (Molty, service account) and metadata-only; print candidate titles/ids/categories/vault names, never fields or values. Prefer exact visible strings from screenshots first: vault name, item title, and field label.

```bash
cat > /tmp/op-find-item.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
set +x
VAULT="Molty"
QUERY="minimax"
OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" \
  op item list --vault "$VAULT" --format json |
  QUERY="$QUERY" VAULT="$VAULT" node -e '
let s=""; process.stdin.on("data",d=>s+=d); process.stdin.on("end",()=>{
  const q=process.env.QUERY.toLowerCase();
  const vault=process.env.VAULT;
  const items=JSON.parse(s).filter(x => [
    x.title, x.id, x.category, ...(x.tags || [])
  ].filter(Boolean).join("\n").toLowerCase().includes(q));
  for (const item of items.slice(0, 10)) {
    console.log(`title:${item.title} id:${item.id} category:${item.category || ""} vault:${vault}`);
  }
  console.log(`matches:${items.length}`);
})'
SCRIPT
chmod 700 /tmp/op-find-item.sh
tmux -S "$SOCKET" send-keys -t "$WIN" -- "bash /tmp/op-find-item.sh; rm -f /tmp/op-find-item.sh" C-m
```

After choosing a candidate, switch back to exact item/field JSON extraction and shape-only validation. No Molty match → desktop consent ask (path 2), never a silent personal-vault read.

## Redacted debugging

Interactive-flow debugging only (consented desktop path). Keep the whole pipeline inside the same task window. Inspect status and output length, never secret values.

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
tmux -S "$SOCKET" send-keys -t "$WIN" -- "bash /tmp/op-debug.sh; rm -f /tmp/op-debug.sh" C-m
```

## Guardrails

- Never paste secrets into logs, chat, or code.
- Path-1 `op` commands always redirect/pipe stdout+stderr; TTY-attached `op` fires a macOS App Data Protection dialog and hangs until answered.
- Every `op` run spawns a background `op daemon` (cache flags do not prevent it in 2.35). Stale daemons can re-trigger the dialog; if popups recur with no op task running, `pkill -f 'op daemon'` is safe. If the dialog appears, answering it once (Allow or Don't Allow) persists; `op` works either way.
- Never `eval "$(op completion zsh)"` unguarded in rc files; it runs `op` on every shell start and is a known dialog-spam source.
- Prefer `op run` / `op inject` over writing secrets to disk.
- Desktop app path only after explicit chat consent; the 1Password unlock prompt then handles the actual authorization — no extra chat round trip at prompt time.
- If sign-in without app integration is needed, use `op account add`.
- If a command returns "account is not signed in" in a consented interactive flow, re-run `op signin` inside tmux and let Peter authorize in the app.
- `sag` only when a consented unlock prompt sits unanswered; never as a pre-alert.
- Do not run `op` outside tmux; stop and ask if tmux is unavailable.
