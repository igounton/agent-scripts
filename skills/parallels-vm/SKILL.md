---
name: parallels-vm
description: Automate and verify Parallels Desktop guests on a macOS host. Covers `prlctl` lifecycle/snapshots/screenshots, guest command execution, website installs, OpenClaw release smoke runs from `openclaw.ai`, macOS/Linux/Windows guest verification wrappers, native Windows no-admin Git bootstrap, SSH bootstrap, and optional Peekaboo GUI automation.
---

# Parallels Desktop

Use this skill for Parallels VM work on a macOS host.

Guest OS split:

- macOS guest: use `prl-macos-*`
- Linux guest: use `prl-linux-*`
- Windows guest: use `prl-windows-*`
- unknown guest: probe with `prlctl exec "<vm>" --current-user sh -lc 'uname -a; cat /etc/os-release 2>/dev/null || true'` before choosing wrappers

Primary tools:

- `prlctl` for power, snapshots, guest exec, guest screenshots, VM info
- `peekaboo` for host-side GUI automation of the Parallels app/window
- `ssh` / Screen Sharing / RDP inside the guest for robust control
- helper wrappers live alongside this skill under `scripts/`; they are not copied into each target repo's `scripts/`

## Fast Path

1. Verify `prlctl` exists: `which prlctl`
2. List VMs: `prlctl list -a`
3. Inspect target VM: `prlctl list -i "<vm>"`
4. Prefer guest-native control first:
   - `prlctl exec "<vm>" --current-user ...`
   - `ssh user@<guest-ip>`
5. Use `peekaboo` only when GUI interaction is required.

Guest exec pitfalls:

- `prlctl exec "<vm>" ...` without `--current-user` often runs as `root`; this is wrong for per-user launchd checks on macOS guests
- `prlctl exec` can have a minimal PATH even with `--current-user`; Homebrew CLIs may fail with `command not found` or `env: node: No such file or directory`
- `prlctl exec` also mangles shell-heavy commands more often than it should on macOS guests; for pipes, redirects, heredocs, or interactive flows, prefer `prlctl enter "<vm>" --current-user --use-advanced-terminal`
- prefer absolute guest paths for Homebrew tools on macOS guests, for example `/opt/homebrew/bin/openclaw`, `/opt/homebrew/bin/node`, `/usr/bin/grep`, `/usr/bin/plutil`
- if you need shell features or user PATH, wrap with a real shell explicitly: `prlctl exec "$VM" --current-user zsh -lc '<cmd>'`
- if a guest-installed npm CLI fails under `prlctl exec` but works interactively, bypass the shebang and run the entrypoint with absolute Node, for example `/opt/homebrew/bin/node /opt/homebrew/lib/node_modules/openclaw/openclaw.mjs ...`
- when validating a same-version npm reinstall inside the guest, use a cache-busted tarball filename and inspect the installed compiled file, not just `--version`; npm may leave the old hashed bundle in place if you keep reinstalling the same filename/version pair
- for host-served current-checkout smoke on Tahoe, use `scripts/prl-host-serve-openclaw.sh` instead of ad-hoc `npm pack` + `python3 -m http.server`; it cache-busts the tarball name, proves `package/dist/build-info.json` matches `HEAD`, and restarts a dedicated host web server cleanly

Reusable helpers:

- `scripts/prl-openclaw-smoke.sh <vm> [--openai-api-key-env <env-var>] [--model <provider/model>] [--install-version <version>] [--install-spec <spec>] [--overlay-spec <spec>] [--overlay-source-dir <guest-package-dir>] [--prefix <guest-prefix>] [--skip-gateway] [--json]`: one-command OpenClaw smoke across macOS/Linux/Windows; auto-detects the guest OS, can do the setup step first, records guest version, optionally pins the primary model, runs an embedded `agent --local --agent main` hatch, and, unless `--skip-gateway` is set, brings up enough gateway state to run a non-local `agent --agent main` reply too
- `scripts/prl-host-serve-openclaw.sh <repo-dir> [--port <port>] [--host <host>] [--out-dir <dir>] [--json]`: build/pack the current checkout when needed, or reuse matching built `dist/`; rename the tgz with `HEAD` + timestamp, verify embedded build-info commit, restart a host-side HTTP server, and print the URL to hand to macOS/Windows install-spec flows
- `scripts/prl-linux-openclaw.sh <vm> [--env KEY=VALUE ...] <openclaw-args...>`: run guest OpenClaw on Linux via resolved CLI path
- `scripts/prl-linux-install-openclaw.sh <vm> [--version latest]`: run the website installer on a Linux guest
- `scripts/prl-linux-gateway-status-version.sh <vm> [--profile <name>] [--state-dir <dir>] [--json]`: fetch Linux guest gateway status and extract `runtimeVersion`, `rpc.ok`, pid, and port data
- `scripts/prl-linux-openclaw-update-verify.sh <vm>`: end-to-end published Linux release smoke using manual gateway verification
- `scripts/prl-macos-enter.sh <vm>`: open a real guest shell via `prlctl enter`
- `scripts/prl-macos-pnpm.sh <vm> <guest-repo-dir> <pnpm args...>`: run guest `pnpm` through absolute Homebrew Node + PATH
- `scripts/prl-macos-vitest.sh <vm> <guest-repo-dir> [--env KEY=VALUE ...] [--] <vitest-args...>`: run guest Vitest via `pnpm exec vitest --root <repo>`; use this instead of hand-rolled guest Vitest commands
- `scripts/prl-macos-repo-openclaw.sh <vm> <guest-repo-dir|guest-entry.js> [--env KEY=VALUE ...] <openclaw-args...>`: run a guest checkout's `openclaw.mjs`/`dist` entry directly; use this for secret-bearing onboard/live commands instead of `pnpm openclaw ...`
- `scripts/prl-macos-live-auth-seed.sh <vm> [--agent <agent-id>] [--guest-path <path>] [--provider <provider:ENV_VAR> ...]`: build a minimal guest `auth-profiles.json` from host env vars and seed it; default providers are `openai:OPENAI_API_KEY` + `anthropic:ANTHROPIC_API_KEY`
- `scripts/prl-macos-download.sh <vm> <url> <guest-path>`: download a URL to a guest file first; safer than `curl | bash` through `prlctl exec`
- `scripts/prl-macos-openclaw.sh <vm> [--env KEY=VALUE ...] <openclaw-args...>`: run guest OpenClaw via absolute Node + resolved entrypoint
- `scripts/prl-macos-install-openclaw.sh <vm> [--version latest] [--spec <npm-spec-or-url>]`: run the website installer reliably inside the guest, or install a host-served/current-checkout tgz directly with absolute guest Node/npm
- `scripts/prl-macos-gateway-status-version.sh <vm> [--profile <name>] [--state-dir <dir>] [--json]`: fetch gateway status and extract `runtimeVersion`, `rpc.ok`, pid, and port data
- `scripts/prl-macos-openclaw-update-verify.sh <vm>`: end-to-end published release smoke; install old version from `openclaw.ai`, verify gateway, update to latest, re-verify, and auto-fallback to manual gateway launch when Tahoe launchd bootstrap is broken
- `scripts/prl-macos-auth-seed.sh <vm> <local-auth-profiles.json|->`: seed `auth-profiles.json` into the guest with base64 transport
- `scripts/prl-windows-install-openclaw.sh <vm> [--version latest] [--spec <npm-spec-or-url>] [--prefix <guest-prefix>]`: run the Windows website installer with `-NoOnboard`, or install a host-served/current-checkout npm spec directly; native installer now bootstraps user-local portable Git under `%LOCALAPPDATA%\OpenClaw\deps\portable-git`, and `--prefix` gives you a clean isolated npm install tree for pre-release smoke
- `scripts/prl-windows-overlay-openclaw.sh <vm> (--spec <npm-spec-or-url> | --source-dir <guest-package-dir>)`: overlay a host-served/current-checkout tgz, or a guest-visible extracted package directory, onto the existing native Windows global install while keeping its `node_modules`; use this when you need upcoming-build code fast and a raw unpacked tgz is missing runtime deps
- `scripts/prl-windows-openclaw.sh <vm> [--prefix <guest-prefix>] [--env KEY=VALUE ...] <openclaw-args...>`: run guest OpenClaw on native Windows; default path uses the encoded PowerShell wrapper, while `--prefix` switches to direct `node --input-type=module` execution against an isolated install tree and avoids flaky `openclaw.cmd` / `--current-user` resolution
- `scripts/prl-windows-gateway-status-version.sh <vm> [--prefix <guest-prefix>] [--json]`: fetch native Windows `gateway status --json`; strips CLIXML and trailing guidance text before parsing
- `scripts/prl-windows-openclaw-update-verify.sh <vm>`: end-to-end native Windows release smoke; can start from a published version or a host-served/local npm spec, attempts `update --json`, tolerates trailing post-JSON guidance text, reports known release blockers, waits for the user session first, and skips the reinstall automatically when the VM is already on the requested `--from-version` unless you pass `--force-reinstall`
- `scripts/prl-windows-onboard-verify.sh <vm> [--prefix <guest-prefix>]`: native Windows onboarding smoke; separates "embedded/provider setup works" from "managed gateway install works", captures expected no-daemon health failures, surfaces Scheduled Task access-denied errors cleanly, and can optionally run an embedded OpenAI hatch in the same wrapper via `--hatch`

## Purpose-Built Wrappers

When the task is about OpenClaw install/update verification, prefer the OS-matched wrappers over ad-hoc `prlctl exec`:

- Cross-OS smoke:
  - `prl-openclaw-smoke.sh`
  - preferred default now: let the smoke wrapper own setup + local hatch + gateway reply, then drop to OS-specific wrappers only when a failure needs install/update/service detail

- Linux guest:
  - `prl-linux-install-openclaw.sh`
  - `prl-linux-openclaw.sh`
  - `prl-linux-gateway-status-version.sh`
  - `prl-linux-openclaw-update-verify.sh`
- macOS guest:
  - `prl-macos-install-openclaw.sh`
  - `prl-macos-openclaw.sh`
  - `prl-macos-gateway-status-version.sh`
  - `prl-macos-openclaw-update-verify.sh`
- Windows guest:
  - `prl-windows-install-openclaw.sh`
  - `prl-windows-overlay-openclaw.sh`
  - `prl-windows-openclaw.sh`
  - `prl-windows-gateway-status-version.sh`
  - `prl-windows-openclaw-update-verify.sh`

- `prl-macos-install-openclaw.sh`: downloads `install.sh` to the guest first, then runs it with explicit PATH/env; `--spec` skips the website installer entirely and does a direct guest `npm install -g <spec>`
- `prl-host-serve-openclaw.sh`: fastest host path for Tahoe current-checkout proof; safe to rerun because the filename always changes and the helper kills/restarts only its own port
- `prl-macos-openclaw.sh`: bypasses shebang/PATH issues by calling guest OpenClaw with absolute Node + `dist/entry.js`
- `prl-macos-gateway-status-version.sh`: normalizes noisy `gateway status --json` output into a compact version/probe summary
- `prl-macos-openclaw-update-verify.sh`: does the Tahoe-style "install old -> verify gateway -> update -> verify gateway" flow and falls back to a detached manual `gateway run` probe after forcing `gateway.mode=local` if LaunchAgent bootstrap fails
- `prl-linux-install-openclaw.sh`: runs the website installer on Ubuntu/Debian-style guests and then resolves the installed `openclaw` CLI path
- `prl-linux-openclaw.sh`: runs guest OpenClaw on Linux via resolved `openclaw` binary path and normal PATH
- `prl-linux-gateway-status-version.sh`: normalizes Linux guest `gateway status --json` output into the same compact summary
- `prl-linux-openclaw-update-verify.sh`: verifies Linux releases with a detached manual `gateway run` path instead of assuming launchd/systemd service setup
- `prl-windows-install-openclaw.sh`: runs the public PowerShell installer with `-NoOnboard`, or installs a local/hosted npm spec directly, relying on the installer's user-local MinGit bootstrap instead of admin `winget` Git; use `--prefix` with `--spec` for a clean per-test install root
- `prl-windows-overlay-openclaw.sh`: overlays a packed build onto the guest's existing global OpenClaw install so the current code can reuse the installed dependency tree; prefer `--source-dir` for the fastest current-build Windows proof when the guest can already see an extracted `package/` folder via `C:\Mac\Home\...`
- `prl-windows-openclaw.sh`: runs native Windows `openclaw` via encoded PowerShell by default, or directly through `node --input-type=module` when you target an isolated `--prefix`; prefer the prefix path for pre-release Windows smoke because it avoids `openclaw.cmd` drift and flaky Parallels `--current-user` lookups
- `prl-windows-gateway-status-version.sh`: returns parsed status JSON even when `gateway status --json` appends human guidance after the JSON block
- `prl-windows-openclaw-update-verify.sh`: captures native Windows version/install/update behavior even when the published release is partially broken; use `--from-spec` and `--update-spec` to keep the whole smoke on host-served artifacts before npm publish, and lean on the built-in skip-reinstall fast path for repeat runs against the same `--from-version`
- `prl-windows-onboard-verify.sh`: use this when the question is specifically "does native Windows onboarding succeed?" because it distinguishes expected local-health failures from real daemon install failures and can optionally prove embedded-provider hatching in one pass
- `prl-macos-auth-seed.sh`: avoids fragile inline JSON writes when a live test needs stored auth profiles

## Core Commands

```bash
VM="<macos-vm-name>"

prlctl start "$VM"
prlctl status "$VM"
prlctl list -i "$VM"
prlctl exec "$VM" --current-user whoami
prlctl capture "$VM" --file /tmp/parallels-shot.png

prlctl snapshot "$VM" --name pre-change
prlctl snapshot-list "$VM" --tree
prlctl snapshot-switch "$VM" --id <snapshot-id>
prlctl snapshot-delete "$VM" --id <snapshot-id>
```

Helper examples:

```bash
VM="<macos-vm-name>"
REPO="$HOME/Projects/openclaw-parallels"

scripts/prl-macos-pnpm.sh "$VM" "$REPO" install
scripts/prl-macos-pnpm.sh "$VM" "$REPO" build
scripts/prl-macos-pnpm.sh "$VM" "$REPO" check
scripts/prl-macos-pnpm.sh "$VM" "$REPO" test
scripts/prl-macos-vitest.sh "$VM" "$REPO" run src/plugins/discovery.test.ts
scripts/prl-macos-repo-openclaw.sh "$VM" "$REPO" --version
source ~/.profile >/dev/null 2>&1
scripts/prl-macos-live-auth-seed.sh "$VM"
scripts/prl-macos-vitest.sh "$VM" "$REPO" --env "OPENCLAW_LIVE_MODELS=openai/gpt-5.4,anthropic/claude-opus-4-6" --env "OPENCLAW_LIVE_TEST=1" --env "CLAWDBOT_LIVE_TEST=1" --env "OPENAI_API_KEY=$OPENAI_API_KEY" --env "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" -- run --config vitest.live.config.ts src/agents/models.profiles.live.test.ts
scripts/prl-macos-vitest.sh "$VM" "$REPO" --env "OPENCLAW_LIVE_GATEWAY_MODELS=openai/gpt-5.4,anthropic/claude-opus-4-6" --env "OPENCLAW_LIVE_TEST=1" --env "CLAWDBOT_LIVE_TEST=1" --env "OPENAI_API_KEY=$OPENAI_API_KEY" --env "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" -- run --config vitest.live.config.ts src/gateway/gateway-models.profiles.live.test.ts
scripts/prl-macos-install-openclaw.sh "$VM" --version 2026.3.7
SPEC="$(scripts/prl-host-serve-openclaw.sh "$PWD")"
scripts/prl-macos-install-openclaw.sh "$VM" --spec "$SPEC"
scripts/prl-openclaw-smoke.sh "$VM" --install-spec "$SPEC" --openai-api-key-env OPENAI_API_KEY --json
scripts/prl-macos-gateway-status-version.sh "$VM" --json
scripts/prl-macos-openclaw-update-verify.sh "$VM" --from-version 2026.3.7 --to-tag latest

VM="Ubuntu 24.04.3 ARM64"
scripts/prl-linux-install-openclaw.sh "$VM" --version 2026.3.7
scripts/prl-linux-gateway-status-version.sh "$VM" --json
scripts/prl-linux-openclaw-update-verify.sh "$VM" --from-version 2026.3.7 --to-tag latest

VM="Windows 11"
source ~/.profile >/dev/null 2>&1
scripts/prl-openclaw-smoke.sh "$VM" --openai-api-key-env OPENAI_API_KEY --model openai/gpt-5.4 --json
scripts/prl-openclaw-smoke.sh "$VM" --install-version latest --openai-api-key-env OPENAI_API_KEY --model openai/gpt-5.4 --json
scripts/prl-openclaw-smoke.sh "$VM" --install-spec "http://<host-ip>:8138/openclaw-next.tgz" --prefix "$PREFIX" --openai-api-key-env OPENAI_API_KEY --model openai/gpt-5.4 --json
scripts/prl-openclaw-smoke.sh "$VM" --overlay-source-dir "C:\Mac\Home\Desktop\openclaw-next-package\package" --openai-api-key-env OPENAI_API_KEY --model openai/gpt-5.4 --json
scripts/prl-windows-install-openclaw.sh "$VM" --version latest
scripts/prl-windows-install-openclaw.sh "$VM" --spec "http://<host-ip>:8138/openclaw-next.tgz"
PREFIX='C:\Users\<user>\AppData\Local\Temp\openclaw-next'
scripts/prl-windows-install-openclaw.sh "$VM" --spec "http://<host-ip>:8138/openclaw-next.tgz" --prefix "$PREFIX"
scripts/prl-windows-overlay-openclaw.sh "$VM" --spec "http://<host-ip>:8138/openclaw-next.tgz"
scripts/prl-windows-overlay-openclaw.sh "$VM" --source-dir "C:\Mac\Home\Desktop\openclaw-next-package\package"
scripts/prl-windows-openclaw.sh "$VM" --version
scripts/prl-windows-openclaw.sh "$VM" --prefix "$PREFIX" --version
scripts/prl-windows-gateway-status-version.sh "$VM" --json
scripts/prl-windows-gateway-status-version.sh "$VM" --prefix "$PREFIX" --json
scripts/prl-windows-onboard-verify.sh "$VM" --json
source ~/.profile >/dev/null 2>&1
scripts/prl-windows-onboard-verify.sh "$VM" --openai-api-key-env OPENAI_API_KEY --hatch --json
scripts/prl-windows-onboard-verify.sh "$VM" --prefix "$PREFIX" --openai-api-key-env OPENAI_API_KEY --hatch --json
scripts/prl-windows-openclaw-update-verify.sh "$VM" --from-version 2026.3.7 --to-tag latest
scripts/prl-windows-openclaw-update-verify.sh "$VM" --from-version 2026.3.7 --skip-install
scripts/prl-windows-openclaw-update-verify.sh "$VM" --from-spec "http://<host-ip>:8138/openclaw-a.tgz" --update-spec "http://<host-ip>:8138/openclaw-b.tgz"
scripts/prl-windows-openclaw-update-verify.sh "$VM" --prefix "$PREFIX" --from-spec "http://<host-ip>:8138/openclaw-a.tgz" --update-spec "http://<host-ip>:8138/openclaw-b.tgz"
scripts/prl-windows-openclaw-update-verify.sh "$VM" --from-version 2026.3.7 --update-spec "http://<host-ip>:8138/openclaw-next.tgz"
scripts/prl-windows-openclaw.sh "$VM" --env "OPENAI_API_KEY=$OPENAI_API_KEY" agent --local --agent main --json --thinking low -m "Reply with exactly WINDOWS-HATCH-OK."
scripts/prl-windows-openclaw.sh "$VM" --env "OPENAI_API_KEY=$OPENAI_API_KEY" agent --agent main --json --thinking low -m "Reply with exactly WINDOWS-GATEWAY-OK."
```

Useful IP extractor:

```bash
vmip() { prlctl list -i "$1" | awk -F': ' '/IP Addresses/{print $2}'; }
```

## SSH Bootstrap

Shared networking is usually enough for host-to-guest SSH. Check guest IP from `prlctl list -i`.

Probe SSH:

```bash
nc -G 2 -vz "$(vmip "$VM")" 22
```

If closed on a macOS guest, enable Remote Login in the guest:

- UI: `System Settings > General > Sharing > Remote Login`
- CLI in guest when creds allow: `sudo systemsetup -setremotelogin on`

Then:

```bash
ssh "$USER@$(vmip "$VM")"
```

If the user wants stable local forwarding like `localhost:2222`, configure a Parallels NAT port-forward rule instead of relying on changing guest IPs.

## macOS Guest Debugging

For launchd-managed services on a macOS guest, use the guest console user, not root:

```bash
VM="<macos-vm-name>"
prlctl exec "$VM" --current-user 'whoami && echo HOME=$HOME && id -u'
```

Gateway / launchd checks that worked well:

```bash
VM="<macos-vm-name>"
prlctl exec "$VM" --current-user 'label=ai.openclaw.gateway; domain=gui/$(id -u); plist=$HOME/Library/LaunchAgents/$label.plist; ls -l "$plist"; launchctl print "$domain/$label"'
prlctl exec "$VM" --current-user 'launchctl print-disabled gui/$(id -u) | /usr/bin/grep -E "ai\\.openclaw|openclaw" || true'
prlctl exec "$VM" --current-user 'lsof -nP -iTCP:18789 -sTCP:LISTEN || true'
prlctl exec "$VM" --current-user 'curl -i --max-time 5 http://127.0.0.1:18789/health || true'
```

Notes:

- `launchctl print gui/$(id -u)/<label>` is the fastest way to prove “plist exists but launchd lost the service”
- `curl http://127.0.0.1:<port>/health` and `lsof -iTCP:<port>` are more reliable than app-specific CLIs when PATH/env inside `prlctl exec` is broken
- if a service CLI fails under `prlctl exec`, first verify whether the binary or its shebang target is missing from PATH before assuming the service is down

OpenClaw/macOS guest notes:

- For OpenAI + Anthropic live model coverage, default to `OPENCLAW_LIVE_MODELS="openai/gpt-5.4,anthropic/claude-opus-4-6"` and `OPENCLAW_LIVE_GATEWAY_MODELS="openai/gpt-5.4,anthropic/claude-opus-4-6"` unless the user asks for different models
- When proving "what version is on main?" from a guest checkout, use `scripts/prl-macos-repo-openclaw.sh "$VM" "$REPO" --version`. `scripts/prl-macos-openclaw.sh "$VM" --version` only checks the guest-global install and may lag or be missing after snapshot restore.
- After `snapshot-switch` / snapshot restore, assume guest repo checkouts and `auth-profiles.json` may be stale or gone. Recreate the checkout, pin it to the host commit under test, and reseed live auth before running gateway live tests.
- Do not trust `prlctl exec` alone to judge installer environment parity on macOS guests. It can miss the interactive shell PATH/init state and falsely report things like missing Homebrew even when the real guest Terminal session sees `/opt/homebrew/bin/brew`.
- Fresh macOS snapshot retests proved the latest stable website installer works in the real interactive guest Terminal: Homebrew is detected, install lands cleanly, and onboarding starts immediately after install. Use that path as the source of truth for `curl -fsSL https://openclaw.ai/install.sh | bash` validation.
- For install smoke on a fresh macOS snapshot, it is normal for `command -v openclaw` to be empty before install. After install, if onboarding starts and the goal is version proof only, `Ctrl-C` the setup flow and run `openclaw --version` in the same guest shell.
- Fresh macOS guests may have Homebrew `node` but no `pnpm`; install once with `/opt/homebrew/bin/node /opt/homebrew/lib/node_modules/npm/bin/npm-cli.js install -g pnpm`
- `scripts/prl-macos-pnpm.sh` now auto-installs missing guest `pnpm` with the guest Homebrew `node`
- Some macOS guests inherit permissive `umask` values (`000`); temp dirs/files can land as `0777`/`0666` and trip OpenClaw's world-writable plugin safety gates. If discovery/loader tests suddenly return no candidates, check permissions first before blaming cache/env logic.
- Prefer argv-style guest commands (`git -C <repo> ...`, wrappers, absolute paths) over `prlctl exec ... sh -lc 'cd ... && ...'`; shell-wrapped git commands on recent macOS guests were flaky here.
- For guest Vitest, prefer `scripts/prl-macos-vitest.sh`; if you do it manually, use `pnpm exec vitest` and pass repo-root-relative test paths under `--root <repo>`.
- For env-scoped guest `pnpm`/Vitest runs, reuse the shared wrapper/lib path (`prl_run_pnpm_env` via `scripts/prl-macos-vitest.sh`) instead of hand-writing `prlctl exec ... env ... node ... pnpm ...` each time.
- `prlctl exec` is fine for argv-style commands; for pipes, heredocs, JSON blobs, or multiline shell work, switch to `scripts/prl-macos-enter.sh`
- Website installer verification should use `scripts/prl-macos-install-openclaw.sh`, not raw `curl | bash` through `prlctl exec`
- Gateway version verification should use `scripts/prl-macos-gateway-status-version.sh`; it strips pre-JSON warnings and reports `runtimeVersion` when present
- Real release smoke should prefer `scripts/prl-macos-openclaw-update-verify.sh`; it now tolerates macOS guest `launchctl bootstrap ... Input/output error` by falling back to a detached manual gateway probe
- Fresh macOS snapshots can start a launchd-managed gateway noticeably slower than a warm machine. On current OpenClaw, `onboard --install-daemon` should allow a longer daemon health window (~45s). If an older build still fails around ~15s but the gateway comes up shortly after, treat that as the old timeout bug, not a bad install.
- Do not add an install-time `launchctl kickstart -k` after a successful `bootstrap` when debugging macOS LaunchAgents. `bootstrap` already loads `RunAtLoad` agents, and on slower guests that extra kickstart can SIGTERM the first gateway process and delay real readiness.
- Released builds may still print `/dev/tty: Device not configured` during noninteractive installer tail work (`doctor` / plugin updates); treat that as a follow-up bug unless the requested version failed to land
- If manual gateway probing is needed, first force `gateway.mode=local`; released builds can otherwise block startup with `set gateway.mode=local (current: unset) or pass --allow-unconfigured`
- For listener checks, use `lsof -nP -iTCP:<port> -sTCP:LISTEN`; plain `lsof -i :<port>` is too noisy on Tahoe
- Avoid `pnpm openclaw ... --openai-api-key ...` / `--anthropic-api-key ...` in guest live setup; `pnpm` echoes the full argv. Use `scripts/prl-macos-repo-openclaw.sh` or direct `node <repo>/openclaw.mjs ...` instead so secrets stay out of logs.
- For exact website-installer validation (`curl -fsSL https://openclaw.ai/install.sh | bash` or `... | bash -s -- --beta`), prefer observing/running inside the guest's real Terminal session or `prl-macos-enter.sh`; treat `prlctl exec` installer failures as suspect until confirmed interactively.
- When reviewing screenshots/logs of installer runs, verify the exact command first. `curl -fsSL https://openclaw.ai/install.sh | bash` is stable; beta requires `bash -s -- --beta`.
- Noninteractive onboarding seeds one provider choice per run. For OpenAI + Anthropic live coverage, run onboard twice or seed `auth-profiles.json` directly.
- For unlanded macOS daemon fixes, prefer `scripts/prl-host-serve-openclaw.sh` plus `scripts/prl-openclaw-smoke.sh --install-spec ...` over manual host tarball serving. It is faster and removes the stale-tarball footgun.
- After a fresh local OpenAI onboard, the first smoke turn may legitimately hit the identity/bootstrap prompt instead of echoing your exact token. `prl-openclaw-smoke.sh` now classifies that as `bootstrapPrompt: true` and treats it as a pass for fresh-snapshot smoke while still surfacing the actual text.
- `src/agents/models.profiles.live.test.ts` can false-green with `"[live-models] no API keys found; skipping"` after a snapshot restore. Treat that as "not actually tested"; pass guest env keys explicitly and verify the log shows real model runs, not a skip.
- `src/gateway/gateway-models.profiles.live.test.ts` currently filters on stored auth profiles; env-only `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` is not enough there. Use `scripts/prl-macos-live-auth-seed.sh "$VM"` (or `prl-macos-auth-seed.sh` with a prepared file) before rerunning.

OpenClaw/Linux notes:

- Linux guests do not use the macOS Homebrew/`dist/entry.js` assumptions; use the `prl-linux-*` wrappers
- Linux release verification uses manual `gateway run` probes, not launchd
- Before assuming Linux support is broken, check whether `openclaw` was installed into `~/.local/bin`, `/usr/local/bin`, or `/usr/bin`
- Ubuntu guest labels in Parallels may lag the actual distro patch level; verify with `/etc/os-release`

OpenClaw/Windows notes:

- Prefer the `prl-windows-*` wrappers; raw `prlctl exec ... powershell -Command` is fragile because quoting and PowerShell execution policy love breaking `npm.ps1` / `pnpm.ps1`
- If you need multiline/native PowerShell work on Windows guests, use the wrapper/lib encoded path, not raw host-shell `powershell -Command "$..."`; host-shell interpolation will happily strip guest `$env:` variables before the command even reaches the VM
- After a hard reboot or snapshot switch, wait until `prlctl exec "$VM" --current-user whoami` works again before trusting wrapper failures; Parallels Tools/user session readiness lags boot
- Right after reboot, plain `prlctl exec "$VM" whoami` may already work as `NT AUTHORITY\\SYSTEM` while `--current-user` still fails; that means the guest booted but the desktop user session is not ready yet
- A black `prlctl capture` right after reboot usually means "guest/session still waking up", not "Windows is dead"
- `prl-windows-onboard-verify.sh` is the right probe for native onboarding. Without `--install-daemon`, a final gateway health failure is expected unless a local gateway is already running.
- Native Windows managed gateway install currently goes through Scheduled Tasks. `schtasks create failed: ERROR: Access is denied.` means admin PowerShell is the blocker, not provider auth.
- Keep embedded hatch/provider checks separate from gateway-service checks. `prl-windows-openclaw.sh "$VM" --env "OPENAI_API_KEY=..." agent --local --agent main ...` can be green while `gateway install` is still red.
- Repeat Windows update tests should prefer `--skip-install` or rely on the default version-match skip path when you only need to re-check the update leg.
- The public Windows installer now bootstraps user-local portable Git under `%LOCALAPPDATA%\OpenClaw\deps\portable-git`; this avoids UAC/admin prompts for Git
- The portable Git bootstrap is process-local; a fresh guest shell may still say `git` is missing unless the installer or wrapper added the portable paths for that command
- For upcoming-build verification, host cache-busted tgz files on the Mac (for example `python3 -m http.server 8138`) and pass them with `prl-windows-install-openclaw.sh --spec ...` or `prl-windows-openclaw-update-verify.sh --from-spec ... --update-spec ...`
- For the cleanest pre-release Windows signal, install host-served tgz files into an isolated temp prefix and keep every later command on that same `--prefix`; this avoids stale `%APPDATA%\\npm` dependency trees and missing `openclaw.cmd` shims after snapshot churn
- Do not unpack a Windows tgz in the guest and run `openclaw.mjs` directly as proof; the tarball expects an installed dependency tree. Use `prl-windows-install-openclaw.sh --spec ...` or `prl-windows-overlay-openclaw.sh --spec ...` instead
- For the fastest current-build Windows proof when the guest already has a working global install, prefer:
  - host: extract the tgz into `~/Desktop/openclaw-<version>-package/package`
  - guest: `prl-windows-overlay-openclaw.sh "$VM" --source-dir "C:\\Mac\\Home\\Desktop\\openclaw-<version>-package\\package"`
  - this avoids slow/opaque guest-side npm global installs from shared folders
- After a reboot, `openclaw.cmd` may not resolve from PATH in a raw guest PowerShell session even though the install is fine; the wrappers already probe `%APPDATA%\\npm` / `%LOCALAPPDATA%\\pnpm` fallback paths, so prefer them over ad-hoc commands
- When `--current-user` guest exec gets flaky on Windows, prefer wrappers that target an isolated `--prefix`; they bypass the shim path and run `openclaw.mjs` directly with guest Node
- For a real OpenAI smoke on native Windows, source `~/.profile` on the host and use the embedded path:
  - `scripts/prl-windows-openclaw.sh "$VM" --env "OPENAI_API_KEY=$OPENAI_API_KEY" agent --local --agent main --json --thinking low -m "Reply with exactly WINDOWS-HATCH-OK."`
- For a full native Windows proof after the gateway is up, use the non-local path too:
  - `scripts/prl-windows-openclaw.sh "$VM" --env "OPENAI_API_KEY=$OPENAI_API_KEY" agent --agent main --json --thinking low -m "Reply with exactly WINDOWS-GATEWAY-OK."`
- Embedded `agent --local` still needs a target; use `--agent main` for the default session. `--model` is not a valid flag here.
- Treat native embedded hatch and native gateway service as separate checks:
  - embedded hatch can pass with only `OPENAI_API_KEY`
  - `onboard --non-interactive --accept-risk ...` still fails at the final loopback gateway probe if the Windows gateway service is not installed/running
- If `gateway install` / `gateway status` are silent through `prlctl exec`, check the direct side effects before assuming failure:
  - `type C:\Users\<user>\.openclaw\gateway.cmd`
  - `if exist C:\Users\<user>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\OpenClaw Gateway.cmd echo STARTUP_PRESENT`
  - `netstat -ano | findstr 18789`
  - if port `18789` is listening and `agent --agent main` returns, count the Windows gateway path as green even if `gateway status` is slow/noisy
- Current published native Windows release (`openclaw@2026.3.11`) can install and report `openclaw --version`, but deeper CLI paths may still fail on Windows ARM with the released `@snazzah/davey` binding load problem
- When you need full native Windows verification today, prefer:
  - website installer for release smoke
  - local tarball/current-checkout install for deeper gateway/plugin/runtime checks
- `prl-windows-openclaw-update-verify.sh` reports these published-release blockers instead of pretending the path is green
- `prl-windows-openclaw-update-verify.sh` and `prl-windows-gateway-status-version.sh` support `--help`; use that instead of bare execution when checking flags

## GUI Automation

Use `prlctl capture` for the guest screenshot itself.

Use Peekaboo for host-side automation of the Parallels window:

```bash
peekaboo see --app Parallels --json
peekaboo click --app Parallels --coords 500,400
peekaboo type --app Parallels "hello"
```

Important:

- `prlctl capture` pixels are guest-native
- `peekaboo click/type` target the visible host window
- coordinate mapping gets fragile if the Parallels window is scaled, moved, fullscreened, or retina-scaled differently

Best practice:

- keep the VM window visible and stable if using Peekaboo
- prefer SSH / Screen Sharing / RDP for serious automation
- use `prlctl send-key-event` only for limited key injection

## Snapshot Safety

- Take a snapshot before risky changes.
- Do not delete or switch snapshots unless asked or clearly part of the requested workflow.
- Call out that snapshot revert discards later guest state.

## Decision Rule

- Need lifecycle / state / metadata / screenshots: use `prlctl`
- Need commands inside guest: use `prlctl exec` or `ssh`
- Need desktop UI control: use guest-native remote control first, Peekaboo second
- Need reproducible visual automation from the host: combine `prlctl capture` for read + Peekaboo for action, but warn about coordinate drift
