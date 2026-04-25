# AGENTS.MD

Work style: telegraph; noun-phrases ok; drop grammar; min tokens.

## Agent Protocol
- Contact: Peter Steinberger (@steipete, steipete@gmail.com).
- Workspace: `~/Projects`. Missing steipete repo: clone `https://github.com/steipete/<repo>.git`.
- 3rd-party/OSS (non-steipete): clone under `~/Projects/oss`.
- `~/Projects/manager`: private ops (domains/DNS, redirects/workers, runbooks).
- “MacBook” / “Mac Studio” => SSH there; find hosts/IPs via `tailscale status`.
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
- Obsidian vault: `$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/steipete-notes`
- Sparkle keys: `~/Library/CloudStorage/Dropbox/Backup/Sparkle`

## Data Sources
- Prefer local archives before web/API for message/history questions; state freshness + gaps.
- `discrawl`: Discord archive/search. DB `~/.discrawl/discrawl.db`; config `~/.discrawl/config.toml`; freshness `sync_state`; check `discrawl doctor`; sync `discrawl sync` / `discrawl sync --full`.
- `slacrawl`: Slack local/API mirror. `slacawl` shim exists; DB `~/.slacrawl/slacrawl.db`; desktop works without tokens; API/full threads/DMs need Slack token env; check `slacrawl doctor`; sync `slacrawl sync --source desktop`.
- `wacrawl`: WhatsApp Desktop archive. DB `~/.wacrawl/wacrawl.db`; source `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared`; read-only; check `wacrawl doctor`; import `wacrawl import`.
- `notcrawl`: Notion SQLite/Markdown mirror. DB `~/.notcrawl/notcrawl.db`; pages `~/.notcrawl/pages`; desktop read-only; API needs `NOTION_TOKEN`; check `notcrawl doctor`; sync `notcrawl sync --source desktop`.
- `beeper`: Beeper/iMessage local history. SQLite `~/Library/Application Support/BeeperTexts/index.db`; inspect `accounts` first; FTS `mx_room_messages_fts`.
- `birdclaw`: X/Twitter archive/inbox. `birdcrawl` shim exists; DB `~/.birdclaw/birdclaw.sqlite`; repo `~/Projects/birdclaw`; `xurl` live reads/writes; check `birdclaw auth status --json`; stats `birdclaw db stats --json`.
- `gog`: Google services CLI. Gmail/Calendar/Drive/Docs/Sheets/Chat when connector insufficient; auth `gog auth list/status`; OAuth creds/keyring under `~/Library/Application Support/gogcli`.
- Env/API keys: check `~/.profile`; secrets/tokens via `op` only inside tmux.

## Docs
- Start: run docs list (`docs:list` script, or `bin/docs-list` here if present; ignore if not installed); open docs before coding.
- Follow links until domain makes sense; honor `Read when` hints.
- Keep notes short; update docs when behavior/API changes (no ship w/o docs).
- Add `read_when` hints on cross-cutting docs.

## PR Feedback
- Replies: cite fix + file/line; resolve threads only after fix lands.
- When merging a PR: thank the contributor in `CHANGELOG.md`.

## Flow & Runtime
- Use repo’s package manager/runtime; no swaps w/o approval.
- Use Codex background for long jobs; tmux only for interactive/persistent (debugger/server).
- Passwords/secrets: check `~/.profile`; `op`/1Password CLI must always run inside `tmux`, never directly.
- `op` recipe: run the whole secret-using command in `tmux`; avoid temp files unless needed, delete after.

## Build / Test
- Before handoff: run full gate (lint/typecheck/tests/docs).
- CI red: `gh run list/view`, rerun, fix, push, repeat til green.
- Release: read `docs/RELEASING.md` (or find best checklist if missing).

## Git
- Safe by default: `git status/diff/log`. Push only when user asks.
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

### gh
- GitHub CLI for PRs/CI/releases. Given issue/PR URL (or `/pull/5`): use `gh`, not web search.

### tmux
- Use only when you need persistence/interaction (debugger/server).
- Quick refs: `tmux new -d -s codex-shell`, `tmux attach -t codex-shell`, `tmux list-sessions`, `tmux kill-session -t codex-shell`.
