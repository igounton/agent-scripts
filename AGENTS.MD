Work style: telegraph; noun-phrases ok; drop grammar; min tokens.
Codex CLI output: avoid Markdown tables by default; they render poorly there. Use short bullets or `key: value` lines instead. Only use a table when explicitly requested.

## Core

- Workspace: `~/Projects`. Missing steipete repo: clone `https://github.com/steipete/<repo>.git`. 3rd-party/OSS: `~/Projects/oss`.
- "Make a note" here => terse `AGENTS.MD` edit. Ignore `CLAUDE.md`.
- `ship` => changelog, commit in groups, push, pull.
- Release closeout: after verified release, bump changelog to next patch `Unreleased`, commit.
- Skills are canonical for tool workflows. Keep this file to hard rules only.
- Editing here/skills: token-efficient, relaxed grammar, terse descriptions.
- Read `~/Projects/agent-scripts/tools.md` when the tool catalog matters.

## Routing

- Screenshots/assets: newest PNG in `~/Desktop` or `~/Downloads`; verify UI before replacing.
- Private/history: local archives first; verify freshness for current questions.
- Secrets: check `~/.profile` anytime you need an API key or for e2e testing; `$one-password` for op/1Password.

## Project Defaults

- Need upstream file: stage in `/tmp/`, then cherry-pick; never overwrite tracked files.
- Bugs: add regression test when it fits.
- Use repo package manager/runtime; no swaps without approval.
- Docs: read repo docs before coding; update docs/changelog for user-visible behavior changes.
- New deps: quick health check for recent releases/commits/adoption.

## PR / CI

- PR refs: use `gh pr view/diff`, not web search.
- PRs: prefer rewriting/fixing the PR, then merging it, over closing and committing equivalent files directly.
- CI: `gh run list/view`; rerun/fix until green when asked.
- Replies: cite fix + file/line; resolve threads only after fix lands.
- User-facing fixes/landed PRs: changelog unless pure test/internal.
- When merging contributor PRs: thank contributor in `CHANGELOG.md`.

## Runtime Safety

- zsh: don't use `status` as a variable.
- 1Password/op: never run `op` directly in a normal shell. Use `$one-password`; no broad enumeration, no secret output.

## Git

- Safe by default: `git status/diff/log`.
- Push only when user asks.
- End in visible checkout/branch user expects.
- Branch changes require user consent.
- Destructive ops forbidden unless explicit: `reset --hard`, `clean`, `restore`, `rm`, etc.
- Commit helper on PATH: `committer` (bash). Prefer it; if repo has `./scripts/committer`, use that.
- Commits: Conventional Commits (`feat|fix|refactor|build|ci|chore|docs|style|perf|test`).
- No repo-wide S/R scripts; keep edits small/reviewable.
- If user types a command ("pull and push"), that's consent for that command.
- No amend unless asked.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
