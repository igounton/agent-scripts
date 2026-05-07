# AGENTS.MD

Work style: telegraph; noun-phrases ok; drop grammar; min tokens.

## Agent Protocol
- Contact: Peter Steinberger (@steipete, steipete@gmail.com).
- Workspace: `~/Projects`. Missing steipete repo: clone `https://github.com/steipete/<repo>.git`.
- 3rd-party/OSS (non-steipete): clone under `~/Projects/oss`.
- `~/Projects/manager`: private ops (domains/DNS, redirects/workers, runbooks).
- “MacBook” / “Mac Studio” => SSH there; find hosts/IPs via `tailscale status`. If Tailscale/SSH host is down or times out, look on LAN: mDNS (`*.local`), `dns-sd -B _ssh._tcp local`, ARP/router leases, then retry SSH with `-o RequestTTY=no -o RemoteCommand=none`.
- Files: repo or `~/Projects/agent-scripts`.
- PRs: use `gh pr view/diff` (no URLs).
- “Make a note” => edit AGENTS.md (shortcut; not a blocker). Ignore `CLAUDE.md`.
- Need upstream file: stage in `/tmp/`, then cherry-pick; never overwrite tracked.
- Bugs: add regression test when it fits.
- Keep files <~500 LOC; split/refactor as needed.
- Commits: Conventional Commits (`feat|fix|refactor|build|ci|chore|docs|style|perf|test`).
- Subagents: read `docs/subagent.md`.
- Editor: `code <path>`.
- CI: `gh run list/view` (rerun/fix til green).
- Prefer end-to-end verify; if blocked, say what’s missing.
- New deps: quick health check (recent releases/commits, adoption).
- Slash cmds: `~/.codex/prompts/`.

## Screenshots (“use a screenshot”)
- Pick newest PNG in `~/Desktop` or `~/Downloads`.
- Verify it’s the right UI (ignore filename).
- Size: `sips -g pixelWidth -g pixelHeight <file>` (prefer 2×).
- Optimize: `imageoptim <file>` (install: `brew install imageoptim-cli`).
- Replace asset; keep dimensions; commit; run gate; verify CI.

## Important Locations
- Blog repo: `~/Projects/steipete.me`
- Notes/Runbooks: `~/Projects/manager/docs/` (e.g. `mac-studio.md`, `mac-vm.md`)
- OpenAI/Codex limits tracking: `~/Documents/steipete/codex limits.md`
- Codex debugging: read local source first: `~/Projects/codex`; start `codex-rs/AGENTS.md`, then targeted `rg` in `codex-rs/{core,tui,exec,cli,app-server,app-server-protocol,config}`.
- Obsidian vault: `~/obsidian`; CLI `notesmd-cli` (`obsidian-cli` shim); default vault `obsidian`; list `notesmd-cli list`, print `notesmd-cli print "Note Title"`, content search `notesmd-cli search-content "term" --format json`.
- Sparkle keys: `~/Library/CloudStorage/Dropbox/Backup/Sparkle`

## Data Sources
- Prefer local archives before web/API for message/history questions; check freshness first; sync when asked; state freshness + gaps.
- `discrawl`: Discord archive/search; use `$discrawl`.
- `slacrawl`: Slack local/API mirror; use `$slacrawl`.
- `whatsapp`: WhatsApp router; use `$whatsapp` first. Primary reads via read-only `wacrawl`; alt accounts/sending via `wacli`.
- `wacrawl`: WhatsApp Desktop archive; read-only; use `$wacrawl` for explicit wacrawl work.
- `notcrawl`: Notion SQLite/Markdown mirror; use `$notcrawl`.
- `imsg`: iMessage/SMS archive + send; send only on request; use `$imsg`.
- `beeper`: Beeper local cache/FTS; use `$beeper`.
- `birdclaw`: X/Twitter archive/inbox; use `$birdclaw` and `$xurl` for live X.
- `gog`: Google services CLI when connectors are insufficient; use `$gog`.
- Env/API keys: check `~/.profile`; secrets/tokens via `op` only inside tmux, and only when strictly needed. Never call `op` directly.

## Docs
- Start: run docs list (`docs:list` script, or `bin/docs-list` here if present; ignore if not installed); open docs before coding.
- Follow links until domain makes sense; honor `Read when` hints.
- Keep notes short; update docs when behavior/API changes (no ship w/o docs).
- Add `read_when` hints on cross-cutting docs.

## PR Feedback
- Replies: cite fix + file/line; resolve threads only after fix lands.
- When merging a PR: thank the contributor in `CHANGELOG.md`.
- User-facing fixes/landed PRs: changelog unless pure test/internal.

## Flow & Runtime
- Use repo’s package manager/runtime; no swaps w/o approval.
- Use Codex background for long jobs; tmux only for interactive/persistent (debugger/server).
- zsh: don't use `status` as a variable.
- Passwords/secrets: check `~/.profile` first. `op`/1Password CLI is last resort, must always run inside `tmux`, never directly.
- NEVER run `op` directly in a normal shell. No exceptions. This includes harmless-looking diagnostics: no direct `op --version`, `op account list`, `op whoami`, `op vault list`, `op item list`, `op read`, or `op item get`.
- `tmux` is necessary for `op`, but not sufficient: do not spam 1Password. No parallel `op`; no repeated probe sessions; no broad vault/item enumeration; no trial-and-error secret discovery.
- Before any `op` call, state the exact single item/field/secret needed and why. If more than one 1Password command seems necessary, stop and ask Peter before continuing.
- Every command whose executable is `op` must run inside one named `tmux` session. The whole pipeline must be inside that `tmux` command: pipes, redirects, command substitution, OTP reads, and publish commands that call `op`.
- Do not probe `op` outside `tmux` to check whether it works. If `tmux` cannot be used, stop and say so.
- `op` recipe: one deliberate `tmux` command; targeted item/field only; avoid temp files unless needed; delete temp files after; inspect only non-secret metadata; keep secret output redacted; kill the tmux session when done.
- Molty service account: `~/.profile` may define `MOLTY_OP_SERVICE_ACCOUNT_TOKEN` for the restricted Molty vault. Use only when the requested secret is known to live there. Service-account `op` reads need an explicit vault, e.g. one tmux-scoped command with `OP_SERVICE_ACCOUNT_TOKEN="$MOLTY_OP_SERVICE_ACCOUNT_TOKEN" op item get "<known item>" --vault Molty ...`; no broad vault/item enumeration, no repeated probes, no repo-stored token, no secret output.
- Remote secret files: stream without printing. If `gh secret set` from stdin stores empty, retry with `--body` from an in-memory shell var after non-secret shape/size checks; verify via workflow evidence that the secret is present.
- OpenClaw Gateway: Peter runs it via a pm2 watcher. Never start/load it via launchd/LaunchAgent on this machine. Do not run `openclaw gateway start/install` or `launchctl bootstrap` for `ai.openclaw.gateway`; if gateway is down, ask before touching the pm2 watcher.

## Build / Test
- Before handoff: run full gate (lint/typecheck/tests/docs).
- CI red: `gh run list/view`, rerun, fix, push, repeat til green.
- Release: read `docs/RELEASING.md` (or find best checklist if missing).

## Git
- Safe by default: `git status/diff/log`. Push only when user asks.
- End in visible checkout/branch user expects; avoid surprise temp worktrees.
- Branch changes require user consent.
- Destructive ops forbidden unless explicit (`reset --hard`, `clean`, `restore`, `rm`, …).
- Remotes under `~/Projects`: prefer HTTPS; flip SSH->HTTPS before pull/push.
- Commit helper on PATH: `committer` (bash). Prefer it; if repo has `./scripts/committer`, use that.
- Don’t delete/rename unexpected stuff; stop + ask.
- No repo-wide S/R scripts; keep edits small/reviewable.
- If user types a command (“pull and push”), that’s consent for that command.
- No amend unless asked.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.

## Tools

Read `~/Projects/agent-scripts/tools.md` for the full tool catalog if it exists.

### peekaboo
- Screen tools: `~/Projects/Peekaboo`. Cmds: `capture`, `see`, `click`, `list`, `tools`, `permissions status`.
- Needs Screen Recording + Accessibility. Docs: `~/Projects/Peekaboo/docs/commands/`.

### committer
- Commit helper (PATH). Stages only listed paths; required here. Repo may also ship `./scripts/committer`.

### mcporter / iterm / firecrawl / XcodeBuildMCP
- MCP launcher: `npx mcporter <server>` (see `npx mcporter --help`). Common: `iterm`, `firecrawl`, `XcodeBuildMCP`.

### imsg
- iMessage/SMS CLI. Use `$imsg`. Send only when explicitly asked.

### gh
- GitHub CLI for PRs/CI/releases. Given issue/PR URL (or `/pull/5`): use `gh`, not web search.

### tmux
- Use only when you need persistence/interaction (debugger/server).
- Quick refs: `tmux new -d -s codex-shell`, `tmux attach -t codex-shell`, `tmux list-sessions`, `tmux kill-session -t codex-shell`.
