Work style: telegraph; noun-phrases ok; drop grammar; min tokens.

## Core

- Workspace: `~/Projects`. Missing steipete repo: clone `https://github.com/steipete/<repo>.git`. 3rd-party/OSS: `~/Projects/oss`.
- `../agent-skills` = `https://github.com/openclaw/agent-skills`, not `steipete/agent-skills`; canonical public OpenClaw shared skills.
- "Make a note" here => terse `AGENTS.MD` edit. No separate `CLAUDE.md` here.
- `ship` => changelog, commit in groups, push, pull.
- Version bumps only on explicit release request. Release = GitHub Release; npm publish too when package applies.
- Release closeout: after verified release, bump changelog to next patch `Unreleased`, commit.
- Release verify: confirm release docs/notes contain changelog; if missing/stale, fix before closeout.
- npm release verify: `npm view <pkg>@<version>` shows version, dist-tag, tarball, integrity, publish time; GitHub tag + Release exist; Release body links npm version page, registry tarball, integrity, CI/proof.
- Changelogs: match file style; prefer one bullet per entry on one line. Do not hard-wrap changelog bullets just because prose is long.
- Skills are canonical for tool workflows. Keep this file to hard rules only.
- Editing here/skills: token-efficient, relaxed grammar, terse descriptions.
- Skill descriptions: short generic trigger phrase, not summary; no personal names, long paths, or workflow narration unless needed for routing.
- Skill frontmatter: quote `description`; after SKILL.md edits, YAML-parse frontmatter before commit.
- Read `~/Projects/agent-scripts/tools.md` when the tool catalog matters.
- Internal handling: private agent conversations and authenticated organization-approved systems are internal contexts. Use task-relevant non-public information there, including internal names, links, systems, processes, and personnel; answering the authorized user is not public exposure.
- External disclosure: never publish, upload, or send non-public organizational information to public audiences, external recipients, or unapproved services without explicit user approval for both content and destination.
- Secrets: never reveal credential or secret values, even internally. Use approved secret tooling and redact outputs.
- Unclear audience/destination: ask before external transmission; confidentiality alone must not block internal research or answers.
- Image uploads: verify destination approval before uploading any image or screenshot. Personal devices: user-requested destinations allowed, subject to external-disclosure rules. Work-managed devices: external uploads default-deny; proceed only when both content and destination are explicitly approved for the device and data classification. Never upload potentially confidential/internal images to social media, public image hosts, or unapproved AI/vision services. Unclear device context, sensitivity, or approval: stop and ask. Local-only processing allowed.
- Personal GitHub repos: use Peter's personal GitHub authorization (`steipete`), not `steipete-oai`, for pushes/writes.
- Peter Macs: expect both GitHub auth contexts to exist on each Mac: `steipete` and `steipete-oai`.

## Routing

- Screenshots/assets: newest PNG in `~/Desktop` or `~/Downloads`; verify UI before replacing.
- Screenshot/live UI bugs: verify with `$browser-use` against the existing Chrome profile. `curl`/source proof is supporting only; no Playwright/Puppeteer/in-app browser for login/profile-dependent pages unless explicitly requested.
- Private/history: local archives first; verify freshness for current questions.
- Secrets/API keys/live creds: use `$one-password`; env only if already exported; `op` is skill/tmux-only, no broad enumeration/secret output.
- 1Password interactive timeout: use `sag` to call Peter aloud; keep tmux/session alive, retry after unlock. Do not silently abandon.
- New API keys: immediately store in 1Password service account via `$one-password`; temp files/env only for current task.
- User-owned Gmail service logins: pre-approved; use saved credentials without asking. Account creation, keys, permissions, and other persistent access remain separate actions.
- Email/Google account for testing: use `gog+clawdbot@gmail.com`.
- OpenClaw deployments: use `service@openclaw.org` accounts only.

## Project Defaults

- Need upstream file: stage in `/tmp/`, then cherry-pick; never overwrite tracked files.
- Bugs: add regression test when it fits.
- Fixes/refactors: delete old paths by default. "Shipped" means in a release Git tag, not main/GitHub/PR. Compat needs explicit contract: public API/CLI/config/data, tagged upgrade path, security boundary, or observed prod state. If unsure, ask before keeping aliases/shims/fallbacks. Tests alone are not contracts.
- Use repo package manager/runtime; no swaps without approval.
- Docs: read repo docs before coding; update docs/changelog for user-visible behavior changes.
- Inline code comments: brief notes for tricky, bug-prone, or previously buggy logic.
- New deps: quick health check for recent releases/commits/adoption.

## PR / CI

- GitHub broad reads: prefer shimmed `gh` / `gitcrawl gh` first. Raw `gh api search/* -f ...` needs `--method GET`; gitcrawl shim sanitizes this.
- Pasted GitHub issue/PR: first `git status -sb`; if dirty, yell; then `git push` + `git pull --ff-only`.
- PR refs: use `gh pr view/diff`, not web search.
- PRs: prefer rewriting/fixing the PR, then merging it, over closing and committing equivalent files directly.
- PR quality: assume generated code may come from weaker AI models. Review and improve the codebase before landing; complete rewrite is acceptable when cleaner.
- Landing own draft PR after explicit land request: ignore draft status; mark ready if needed and continue.
- `fix ci`: consent to pull, commit, push; fix/rerun/watch until CI green.
- CI: `gh run list/view`; rerun/fix until green when asked.
- `rewrite commits + land`: clean stack, agreed focused proof only, force-push, merge. No Codex review, PR-body proof polish, or CI babysitting unless asked.
- Pre-land/pre-commit code changes: use `$autoreview` until no accepted/actionable findings remain, unless equivalent manual review already done, trivial/docs-only, or user opts out.
- Replies: cite fix + file/line; resolve threads only after fix lands.
- Issue fixed on `main` with proof: comment proof + commit/PR, then close.
- User-facing fixes/landed PRs: changelog unless pure test/internal.
- Contributor PR authors should not edit changelog; maintainer/AI adds entry at merge.
- After landing: final includes 2-5 sentence recap of what landed.
- After landing: checkout `main`, pull `--ff-only`, verify `git status -sb`, then final.
- When merging contributor PRs: thank contributor in `CHANGELOG.md`.
- Unpushable contributor PRs (`maintainerCanModify=false`/no head write): if fixups needed, recreate locally from PR head/diff, make one maintainer commit, push it, then close PR with comment.
- Preserve contributor credit: commit body includes `Co-authored-by: Name <email>` from PR commit author; changelog still thanks `@login` when user-facing.
- PR fixups from repo cwd: use that checkout. No worktrees unless asked; if awkward, ask.
- Close comment: link landed commit, explain PR branch could not be updated, thank author, suggest enabling "Allow edits by maintainers" for future PRs.

## Runtime Safety

- zsh: don't use `status` as a variable.
- zsh: loop multi-item lists as arrays; scalar strings do not word-split like bash.
- Public GitHub bodies: never inline double-quoted text with backticks, `$`, shell snippets, env names, or user text. Use temp file + `cat <<'EOF'` + inspect + `--body-file`.
- PR/issue body edits: fetch via REST + `jq -r`, never `gh pr/issue view --json body --jq .body`. Example: `gh api repos/OWNER/REPO/pulls/NUM | jq -r '.body // ""' > /tmp/body.md`; inspect before `--body-file`; stop if it starts with `"` or shows literal `\n`.
- Secrets: never run `env`, `set`, `export -p`, or broad secret regex dumps in a normal shell. Query exact names only; redact values.
- After touching secrets/env, public `gh` writes use token env unset where possible: `env -u GITHUB_TOKEN -u GH_TOKEN -u HOMEBREW_GITHUB_API_TOKEN ...`.

## Git

- If cwd is in a git repo: work there. Do not jump to sibling checkout unless asked.
- No `git worktree` from CLI sessions unless user asks. If dirty/wrong branch/awkward: ask.
- Branch switch/checkout ok when task needs it and repo rules allow.
- `~/Projects` has many intentional same-repo checkouts. Treat as user-managed, not scratch.
- If cwd is not a git repo: freeform; pick sensible folder, say path before edits. Worktrees ok if useful.
- Safe by default: `git status/diff/log`.
- Push only when user asks.
- End in visible checkout/branch user expects.
- Branch changes require user consent.
- Destructive ops forbidden unless explicit: `reset --hard`, `clean`, `restore`, `rm`, etc.
- Commit helper on PATH: `committer` (bash). Prefer it; if repo has `./scripts/committer`, use that.
- Commits: Conventional Commits (`feat|fix|refactor|build|ci|chore|docs|style|perf|test`).
- Locked Mac / Secretive failure: use HTTPS transport; retry signing-blocked commits with `--no-gpg-sign`.
- No repo-wide S/R scripts; keep edits small/reviewable.
- If user types a command ("pull and push"), that's consent for that command.
- No amend unless asked.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
