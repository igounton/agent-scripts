---
name: clownfish-cloud-pr
description: Use when launching Clownfish in GitHub Actions to create or update one guarded GitHub implementation PR from issue/PR refs, a ClawSweeper report, or a custom maintainer prompt.
---

# Clownfish Cloud PR

Use this skill when the user wants Codex to ask Clownfish to create a PR in the
cloud from issue/PR refs plus a custom prompt.

## Start

```bash
cd ~/Projects/clownfish
git status --short --branch
gh variable list --repo openclaw/clownfish --json name,value \
  --jq 'map(select(.name|test("^CLOWNFISH_"))) | sort_by(.name) | .[] | {name,value}'
```

Keep merge gated unless Peter explicitly opens it. Normal fix-PR work wants
`CLOWNFISH_ALLOW_EXECUTE=1`, `CLOWNFISH_ALLOW_FIX_PR=1`, and
`CLOWNFISH_ALLOW_MERGE=0`.

## Create One Job

From refs and a custom prompt:

```bash
npm run create-job -- \
  --repo openclaw/openclaw \
  --refs 123,456 \
  --prompt-file /tmp/clownfish-prompt.md
```

From a ClawSweeper report:

```bash
npm run create-job -- \
  --from-report ../clawsweeper/records/openclaw-openclaw/items/123.md
```

The script checks for an existing open PR/body match and remote branch named
`clownfish/<cluster-id>` before writing a duplicate job. Use `--dry-run` to
inspect the exact job body and `--force` only after deciding the duplicate check
is stale.

## Validate And Dispatch

```bash
npm run validate:job -- jobs/openclaw/inbox/clawsweeper-openclaw-openclaw-123.md
npm run render -- jobs/openclaw/inbox/clawsweeper-openclaw-openclaw-123.md --mode autonomous >/tmp/clownfish-rendered-prompt.md
git add jobs/openclaw/inbox/clawsweeper-openclaw-openclaw-123.md
git commit -m "chore: add ClawSweeper promoted job"
git push origin main
npm run dispatch -- jobs/openclaw/inbox/clawsweeper-openclaw-openclaw-123.md \
  --mode autonomous \
  --runner blacksmith-4vcpu-ubuntu-2404 \
  --execution-runner blacksmith-16vcpu-ubuntu-2404 \
  --model gpt-5.5
```

Do not use `--dispatch` until the job file is already committed and pushed; the
workflow reads the job path from GitHub, not the local filesystem.

## Monitor

```bash
gh run list --repo openclaw/clownfish --workflow cluster-worker.yml --limit 10 \
  --json databaseId,status,conclusion,createdAt,updatedAt,url,displayTitle
```

After a run completes, download and review artifacts before scaling:

```bash
rm -rf /tmp/clownfish-check-RUN_ID
mkdir -p /tmp/clownfish-check-RUN_ID
gh run download RUN_ID --repo openclaw/clownfish --dir /tmp/clownfish-check-RUN_ID
npm run review-results -- /tmp/clownfish-check-RUN_ID
```

## Maintainer Comment Commands

Clownfish also responds to maintainer-only target repo comments routed by
`npm run comment-router`.

Accepted triggers:

```text
/clownfish status
/clownfish fix ci
/clownfish address review
/clownfish rebase
/clownfish explain
/clownfish stop
@openclaw-clownfish fix ci
```

Do not use `@clownfish`; that is a separate GitHub user. The accepted mention is
`@openclaw-clownfish` or `@openclaw-clownfish[bot]`.

The router only accepts maintainer comments by default:
`OWNER`, `MEMBER`, or `COLLABORATOR`. Contributor comments are ignored without a
reply. Repair commands dispatch the normal `cluster-worker.yml` path only for
existing Clownfish PRs identified by the `clownfish` label or `clownfish/*`
branch.

Dry-run or execute the router:

```bash
npm run comment-router -- --repo openclaw/openclaw --lookback-minutes 180
npm run comment-router -- --repo openclaw/openclaw --execute --wait-for-capacity
```

Scheduled routing is dry by default. Set
`CLOWNFISH_COMMENT_ROUTER_EXECUTE=1` in `openclaw/clownfish` repo variables to
let scheduled runs post replies and dispatch workers.

## Guardrails

- One cluster, one branch, one PR: `clownfish/<cluster-id>`.
- No security-sensitive work; route vulnerability, secret, auth bypass, RCE,
  XSS/CSRF/SSRF, exploitability, and sensitive-data exposure elsewhere.
- Do not merge from Clownfish unless Peter explicitly asks.
- Do not close duplicates before the fix PR path exists, lands, or is proven
  unnecessary.
- Codex workers do not get GitHub tokens; deterministic scripts own writes.
