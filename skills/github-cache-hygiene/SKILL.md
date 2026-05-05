---
name: github-cache-hygiene
description: Use when GitHub work may hit rate limits, when using gh for issues/PRs/actions, or when a task mentions ghx, gh xcache, gitcrawl, caching, local GitHub mirrors, quota pressure, or many Codex agents.
---

# GitHub Cache Hygiene

Goal: answer common GitHub read questions from gitcrawl and the `gh` shim first, then spend live GitHub API calls only where freshness or writes matter.

## Default Path

Use `gh` normally. On Peter's machines it is expected to be the gitcrawl-backed shim, so supported reads can be answered locally or cached without changing commands.

Prefer these local/cached reads:

```bash
gitcrawl sync owner/repo --numbers 123 --with pr-details
gh search issues "<terms>" -R owner/repo --state open --json number,title,state,url,updatedAt,labels,author
gh search prs "<terms>" -R owner/repo --state open --json number,title,state,url,updatedAt,isDraft,author
gh issue list -R owner/repo --state open --author user --assignee user --label bug --json number,title,url
gh pr list -R owner/repo --state open --author user --label dependencies --json number,title,url
gh issue view 123 -R owner/repo --json number,title,state,body,comments,labels,url
gh pr view 123 -R owner/repo --json number,title,state,body,comments,labels,files,commits,statusCheckRollup,url
gh pr checks 123 -R owner/repo --json name,state,detailsUrl,workflow
gh run list -R owner/repo --branch branch-name --json databaseId,workflowName,status,conclusion,url
gh pr diff 123 -R owner/repo --patch
```

Use exact refs and narrow fields. Avoid broad loops like one `gh issue view` per result when a single `gh search` or `gh issue list --json ...` can answer the first-pass question.

For CI, avoid tight `gh run list` / `gh run view` polling loops. After a push or workflow dispatch, identify one exact run, then poll it with backoff. Fetch full logs only for failed jobs or when the user explicitly asks for logs. Completed-style `gh run view --log`, `--log-failed`, and common Actions REST log endpoints are cached longer by gitcrawl, while run status stays short-lived.

## Freshness

Local answers are good for discovery, duplicate search, old thread review, author/label triage, and "is there likely already an issue/PR?" checks.

Use a live call when:

- writing, commenting, closing, merging, rerunning, or editing
- checking final current state before a maintainer action
- verifying CI status after a push
- the local result is missing or obviously stale
- the user asks for latest/live state

For PR review, prefer hydrating exact PR details once with `gitcrawl sync owner/repo --numbers <n> --with pr-details` when you know you will inspect files, commits, checks, or run summaries repeatedly. The `gh` shim can auto-hydrate one exact PR on miss, using `GITHUB_TOKEN` or `gh auth token`; explicit hydration makes intent and cost clearer.

After a write, do one targeted readback, not a broad rescan.

## XCache

Inspect cache behavior when rate limits are suspected:

```bash
gh xcache stats
gh xcache keys
gh xcache gc
```

Read `backend_misses_by_command` and `backend_misses_by_route` in `gh xcache stats --json` before adding new live GitHub loops. Those maps show which command shapes are still escaping the cache.

Use `gh xcache flush` only when a stale cached fallback read is misleading a decision.

For local-only proof, temporarily make the backend unavailable for a single command:

```bash
GITCRAWL_GH_PATH=/tmp/no-real-gh gh search issues "<terms>" -R owner/repo --json number,title,url
```

## Agent Etiquette

Batch questions by repo and state. Reuse data already printed in the session. Back off CI polling; inspect logs only for failing runs or the exact run under review. Do not bypass the shim with `/opt/homebrew/opt/gh/bin/gh` unless diagnosing the shim itself.
