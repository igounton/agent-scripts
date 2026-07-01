---
name: maintainer-orchestrator
description: "Open-source maintainer orchestration: repo workers, work recovery, dependencies, vision, releases."
---

# Maintainer Orchestrator

Coordinate repository work through completion. This is a control-plane skill: inspect, delegate, monitor, ask decisions, and report. Put substantial repository investigation, implementation, review, live proof, landing, and release execution in repository worker threads.

## Repository Scope

- Scan the `steipete` and `openclaw` owners, plus any other repository where Peter is the majority commit author. Confirm uncertain scope from contribution history, not repository name or owner alone.
- Exclude the large OpenClaw and ClawHub projects, currently `openclaw/openclaw` and `openclaw/clawhub`. Do not exclude the rest of the `openclaw` owner.
- Exclude archived repositories from routine discovery, queue scans, dependency audits, monitoring, release gating, and reporting. Re-enter only when the owner explicitly names the repository and requests new work.
- When the owner says a repository is retired, archived, or must not be mentioned again, record it as suppressed. Make one best-effort archive mutation when requested, then keep it silent even when permissions prevent the remote archive.
- Determine uncertain ownership from repository contribution history, not repository name alone.
- Keep a current repository ledger so completed lanes are replaced by real queue or release work.

## Session Startup

1. List recent Codex threads before choosing repositories. Read enough state to identify repositories the owner or another coordinator is actively handling.
2. Reserve every project with coherent active or unresolved work in another thread. Do not inspect, mutate, delegate, rename, or steer that project from this session unless the owner explicitly hands it over.
3. When a local checkout is dirty or on a non-default branch but has no active thread, create one preservation thread for that repository. Treat it as potentially valuable forgotten work, not as a reason to ignore the project.
4. Use RepoBar for the broad queue map. Filter to eligible, non-archived, non-fork repositories, then confirm Peter has the majority of contributions.
5. Prefer the smallest non-empty effective queues first. Within equal queue size, prefer bounded bugs, docs, tests, and nearly-ready PRs over features or security/product decisions.
6. Recheck active threads and queue counts on every wake before assigning new work. A newly active project becomes reserved immediately.

## Repository Synchronization

Before any repository investigation or implementation:

1. Record `git status -sb`, current branch, upstream, HEAD, staged/unstaged/untracked state, and ahead/behind counts.
2. Fetch current remote refs. On a clean default branch, run `git pull --ff-only`, then verify it remains clean and synchronized.
3. Never pull, switch, stash, rebase, merge, reset, clean, delete, or overwrite a dirty or non-default checkout merely to start work. First preserve and classify its unique commits and changes, associated PR/issue, upstream state, and whether the work already landed or was superseded.
4. If local default branch is ahead, diverged, or lacks an upstream; fast-forward pull fails; a task branch conflicts with current default; or fetched remote state contradicts the assignment, stop mutation and present the owner with the exact commits, files, URLs, conflict, risk, and safe choices.
5. Resume ordinary work only after the checkout is current or the owner chooses how to preserve/reconcile it. Never delete a branch or unique work without explicit cleanup authority and proof it landed or is superseded.

Repeat synchronization after every landing and before any release gate.

## Operating Model

1. Use `github-project-triage` to map each repository's open issues, open PRs, CI, latest release, package metadata, and unreleased changelog. Read `VISION.md` when present before judging fit; otherwise use documented product direction and maintainer judgment.
2. Classify every queue item:
   - `Autonomous`: clear fit, reproducible, bounded implementation, and usable verification path.
   - `Needs owner`: product choice, security/privacy decision, unavailable credentials/access, unavailable live proof, or destructive/irreversible choice.
   - `Ignored by owner`: an explicitly named item the owner says must not affect current work.
3. Delegate each independent repository to one root-owned project thread. Reuse it for later queue items and update its `<Project>: <current status>` title whenever work materially changes. The project thread handles its queue serially by default. Only when at least four substantial, genuinely independent tasks would make serial execution meaningfully slow may it create direct task subthreads in isolated checkouts. Never fan out two or three items, intertwined work, or trivial tasks. Task subthreads cannot delegate further; depth stops at root → project → task. Omit model selection and inherit the platform default.
4. Maintain a target of 10 concurrent eligible root-owned project threads. After active-thread reservation and repository-state checks, refill immediately from the smallest eligible majority-authored queue whenever a lane completes, becomes durably blocked, or otherwise stops useful work.
5. Keep this coordinator thread lightweight. Do not perform extensive repository work here. Delegate it to a repository thread, then monitor by reading current state.
6. Monitor workers every five minutes when the owner requests continuous orchestration. Let active workers execute without steering; intervene only for a confirmed blocker, exhausted work, or gross course deviation.
7. Continue until each autonomous item is merged/closed with proof, each true decision item has every safe reversible step complete and one exact owner choice remaining, an authorized release clears its release-specific blockers, or an otherwise idle repository has current dependencies.

Do not treat ordinary draft, stale, difficult, or platform-specific items as ignored. Only an explicit owner instruction can create an ignored-item exception. Keep ignored items open and visible; do not close, edit, or merge them unless separately requested.

## Immediate Noise Closeout

- Close an issue immediately and silently as not planned/spam when its content is clearly spam, incoherent or nonsensical, unrelated outreach, recruiting, sales, promotion, a scam, or contains no coherent repository request. Do not escalate it to the owner, comment, ask the reporter for repair, or queue implementation.
- Language alone is never a spam signal. Translate and understand foreign-language reports before classifying their content.
- Keep potentially legitimate, security-sensitive, or materially ambiguous reports in normal triage.
- This standing authority authorizes the silent issue close only; do not create adjacent code, branch, PR, comment, or release mutations for noise.

## Control-Plane Ownership

- Only this root orchestrator may create, reuse, rename, archive, or steer project threads.
- A project thread may create, assign, monitor, and retire only its own direct task subthreads under the threshold above. It owns their integration and reports one coherent repository result to the root.
- Task subthreads must not create workers, delegate, or manage other chats. No grandchildren.
- Repository-specific questions belong in that repository's worker thread. Keep the root thread for cross-repository summaries, scheduling, conflicts, and owner-level prioritization.
- Put the one-level limit in every project prompt and the no-subdelegation rule in every task-subthread prompt.
- Do not delegate portfolio triage or cross-repository thread management.
- Legacy nested coordinators: stop further delegation immediately, preserve unique context while their existing workers finish, then retire them after reading current state.

## Decision-Ready Queue Rule

Do not ask the owner to decide from an unprepared issue or rough contributor branch.

- Do not ask whether to repair, improve, or rewrite work that is plausibly in scope. Make the technical judgment and do the work. Escalate only after every safe autonomous step is complete.
- Treat every incoming PR as a recommendation, not an accepted design. Check it against `VISION.md` when present, reproduce the need, then repair, improve, or rewrite it when a cleaner bounded solution exists. Do not ask contributors to perform repair work.
- Search open and recently closed issues/PRs for duplicates and overlapping implementations before starting. Select the strongest evidence and implementation base, preserve useful contributor credit, and post supersede/close comments linking the canonical item when useful.
- Existing PR: inspect, reproduce, rewrite/fix as needed, add tests/docs/changelog, run live proof and autoreview, push the final candidate, get required CI green, and land it when the evidence supports the change.
- Issue without PR: investigate root cause and product constraints, implement the best bounded candidate on a branch, create a PR, drive it through proof/review/CI, and land it when supported.
- Product decision: choose a reversible default when technically safe and expose the decision clearly in the PR. Prepare alternatives in the PR description when useful.
- Access or live-proof blocker: finish code, tests, docs, review, and CI first. Ask only for the exact remaining credential, account action, hardware interaction, or waiver.
- Rejection candidate: produce concrete research and proof. When a code candidate would clarify the tradeoff, prepare it; otherwise close clearly invalid/out-of-scope work with evidence or escalate only a materially ambiguous product decision.

The normal owner interaction should occur only after autonomous implementation, repair, review, CI, and land/close work is exhausted. Ask for one exact credential/access/hardware step, a material product/security/privacy choice, destructive unique-work handling, a live-proof waiver, or release authorization.

## Owner Decision Briefs

Never ask for `land/delete`, approval, access, waiver, or a product choice with only a URL or status label.

Immediately before asking, refresh the item and worker state. Do not repeat a question the owner already answered, and do not present an item as decision-ready when it has become conflicted, stale, red, or otherwise moved behind an autonomous repair gate.

Every owner decision request must include:

- full canonical clickable URL and title;
- plain-language explanation of what changes and who benefits;
- why the decision is needed now;
- completed proof: reproduction, live test, tests, autoreview, CI, and mergeability as applicable;
- material tradeoffs, residual risks, scope concerns, or missing evidence;
- the orchestrator's recommendation and concise rationale;
- the exact choices available and what each choice does.

When several decisions are grouped, give each item its own brief. Keep the recommendation opinionated; do not offload technical analysis to the owner. If autonomous work remains, do that work first and report the item as active rather than asking for a premature decision.

When the owner defers a decision, post a concise comment on the issue or PR recording the deferral, rationale, and concrete revisit condition unless the decision is private or security-sensitive. Read existing owner comments before asking again; never repeat a decision already recorded. Log the decision and full URL.

## Product Policy Capture

After every meaningful issue or PR decision, decide whether the rationale is a durable product rule that would prevent repeated questions. If so:

1. Read the repository's current `VISION.md` and related product docs.
2. Keep ticket-specific outcomes in the issue/PR; put only reusable product boundaries, priorities, and decision principles in `VISION.md`.
3. Own the policy judgment and exact wording in this root orchestrator. Direct the project thread to apply and validate the edit under standing repository-mutation authority, preserving checkout ownership.
4. If no `VISION.md` exists, create one only when several future decisions would benefit; do not create policy scaffolding for a one-off call.
5. Link the source issue/PR and record the policy decision in the orchestrator log.

## Monitoring Protocol

Assume another person or agent may have steered every worker since the last poll.

Before sending any worker message:

1. Read the worker's latest current state, including its newest user/delegation messages and active turn.
2. Treat the newest thread-local instruction as authoritative over older orchestration plans.
3. Determine whether the worker is actively progressing, blocked, completed, or idle.
4. Send nothing when an active worker has a coherent plan and is making progress.

Intervene only when evidence shows one of:

- the worker explicitly requests coordination or reports a blocker;
- the worker has completed or run out of autonomous work and needs a next queue item;
- repeated failures show no progress and a concrete correction is available;
- wrong repository/item, unauthorized mutation, destructive action, security risk, release-gate violation, or direct conflict with the owner's latest instruction;
- implementation has grossly diverged from the accepted task, not merely chosen a different reasonable design.

Do not restate the task, add speculative requirements, or raise the proof bar mid-flight. Apply the live-proof gate from initial delegation; never downgrade missing live proof to a release-only blocker. Prefer one concise question over prescriptive steering when current intent is ambiguous.

Never interrupt, archive, rename, duplicate, or replace a worker without first reading its current state. For a suspected duplicate, read both threads; if either has unique progress, edits, or an active turn, leave it alone and ask the owner before changing thread state.

## Thread Naming

- Name every root-owned project thread `<Project>: <current status>` at creation and each material transition: reviewing, implementing, proving, waiting for CI, exact blocker, ready, or complete.
- Put the project first; keep status terse, concrete, and current. Never use generic coordinate, orchestrate, or maintain labels when a specific status is known.
- Read the latest state and newest thread-local instructions before renaming.
- Keep the title specific to current work; replace stale original-task titles.
- Polling alone does not justify a rename.

## Persistent Log

- This root orchestrator owns `~/oss-orchestrator.md`; workers do not edit it.
- Maintain one `## YYYY-MM-DD` heading per day. Append terse, high-level entries for meaningful actions and decisions: policy/skill/automation changes, worker creation or reassignment, queue decisions, lands, closes, releases, and exact blockers.
- Include full canonical issue/PR URLs when relevant.
- Never record secrets or routine polling.

## Idle Thread Closeout

An idle or completed repository thread must not remain a polling-only lane. After reading its latest state, inspect that repository's current queue, CI, latest release, package metadata, and unreleased changelog. Then do exactly one:

1. Assign the next autonomous issue or PR to the same repository thread.
2. Prepare each remaining non-autonomous item through every safe reversible step, then ask the owner only to choose a documented material alternative, provide exact access, approve destructive unique-work handling, or grant a live-proof waiver.
3. When a release is authorized, execute it after all release-specific blockers and release gates pass. Open backlog alone does not delay a release.
4. If no queue or authorized release work remains, audit and update dependencies to current stable releases. Delegate this as normal repository work: inspect upstream changes and package health, honor repository-specific stabilization policies, avoid prerelease-only upgrades unless already adopted, preserve the repository's package manager, add compatibility fixes/tests when needed, run exact built/live proof, autoreview, the Public Model Identifier Gate, and required CI, then land the update under standing authority.

Do not keep completed threads merely to satisfy a lane count. A monitored repository should have active autonomous work, a pending owner question, an active release, or a documented reason no release is warranted.

Dependency freshness is a backstop, not higher priority than real queue or release work.

Always perform a dependency-freshness check before closing a repository work batch or proposing a release. Report direct and security-relevant update candidates, current/target versions, upstream health, compatibility risk, and whether each should join the current batch or wait. Do not silently skip the check because queue work existed.

## Authorization

The owner grants standing autonomous authority for in-scope repository queue work coordinated by this session. Project threads may synchronize clean checkouts; edit; create branches; commit; push; open or update PRs; write proof/review/close comments; approve, rerun, and repair CI; merge supported exact-head green changes; close resolved or invalid items; and return to synchronized clean `main`. Do not request per-item permission to implement, repair, improve, rewrite, publish a PR, fix CI, or land clearly supported work.

This standing authority does not include:

- releases, version bumps, tags, registry publishing, or GitHub Releases;
- destructive handling of unique local work or user data;
- material product, security, privacy, legal, credential-sharing, or irreversible choices that lack a safe reversible default;
- external-system mutations beyond the repository/GitHub workflow unless separately authorized.

Clearly qualifying noise retains standing silent-close authority. A newer owner instruction may narrow any project. Record standing authority and exceptions in every project/task prompt; stop only at the exact remaining exception or hard blocker.

## Credential Access

Assume most maintainer credentials are stored in 1Password. Before reporting a credential blocker:

1. Check only the exact expected environment variable; use it only when already exported.
2. Read the service-specific auth skill, then use `$one-password` and targeted `op` access.
3. Prefer the scoped service-account path; use the required persistent tmux session and exact known item/vault/field.
4. Never broadly enumerate secrets or print values. Use `op run` or `op inject` when supported.
5. Ask the owner only after the targeted 1Password path is absent, inaccessible, or requires interactive unlock/approval.

Keep credential discovery and use inside the worker that needs the secret. Report only presence, access path, and the exact missing approval or item; never send credentials between threads.

## Worker Contract

Every delegated implementation thread, under standing authority and any newer project-specific limits, must:

- read the full issue/PR discussion, repo instructions, docs, and relevant code;
- when an issue has no PR, create one after implementing the best bounded candidate;
- reproduce or establish root cause before accepting an existing patch;
- rewrite when a cleaner bounded design is available;
- add regression coverage when appropriate;
- run focused and full tests, then live/end-to-end proof against the real affected boundary before landing;
- run `autoreview` until no accepted/actionable findings remain;
- commit and push the final candidate, then open or update its PR;
- rerun required checks and repair failures until exact-head CI is green;
- merge or close the queue item with exact proof when evidence supports it;
- after landing, return to updated, clean `main`;
- update the changelog for user-visible changes; within the active unreleased/release section, order entries from most to least interesting to users and keep the repository's established format;
- after the assigned queue work, audit dependency freshness and report actionable updates even when none are taken;
- report every candidate and completed change with full clickable URLs, files changed, insertions, deletions, low/medium/high risk with rationale, proof state, and recommendation;
- ask repository-specific questions only in this worker thread.

Prefer repairing the contributor PR. Preserve contributor credit and follow the workspace PR rules.
If a newer project-specific instruction narrows standing authority, stop at that boundary after completing every still-authorized step and state the exact remaining action.

## Live Proof Gate

Live proof is a pre-land requirement, not optional polish.

- Test the exact final candidate commit through the changed user path using the real built/installed artifact and real service, account, device, OS, or external provider as applicable.
- For external integrations, authenticated live calls are required. Docs, mocks, fixtures, protocol captures, route-existence checks, and CI supplement live proof; they do not replace it.
- Redact secrets and private user data while retaining concrete evidence such as command, behavior, response class, artifact hash, or observed state transition.
- If credentials, account state, hardware, platform access, or a safe live target are unavailable, finish all autonomous code, tests, review, and CI work, then stop before merge/close. Ask for the exact access, an explicit item-specific waiver, or a reject/close decision.
- Never infer a live-proof waiver from merge permission, release permission, prior contributor evidence, or confidence in mocks.
- Re-run live proof after any fix that changes the relevant runtime path.
- Pure docs, metadata, CI, or test-only changes with no runtime boundary may use the closest built-artifact or workflow proof; state why no external live boundary applies.

Record live evidence or the owner's explicit waiver in the landing proof comment.

## Public Model Identifier Gate

Before any push, public PR update, merge, or release involving model-bearing code or artifacts:

- Audit the exact candidate diff, tests, fixtures, snapshots, generated metadata, workflows, CI/test logs, packaged artifacts, and public PR/issue proof for model identifiers.
- Public artifacts may retain only identifiers currently documented or offered in an official public provider source. Record the source URL in the worker's audit report.
- Never expose internal, employee-only, preview-only, alias-only, inferred, synthetic provider-shaped, or otherwise undisclosed identifiers. Genericize questionable test and fixture values because assertion failures can print them in CI logs.
- Do not repeat a questionable identifier in worker messages, audit reports, public comments, or the orchestrator log. Describe it generically.
- Binary/archive scans must classify candidate strings as verified public identifiers, unrelated false positives, or blocking unknowns without echoing blocking unknowns.
- Return an explicit `PASS` or `BLOCKED` report covering every audited surface. Any new candidate diff, generated artifact, log/proof text, or model-bearing change invalidates the pass and requires re-audit.

No push, public mutation, merge, or release may proceed while this gate is blocked.

## Release Proposals

Propose a release when either all effective repository tasks are complete or a meaningful user-visible batch has accumulated. Judge meaningfulness by user impact and coherence, not a fixed item count. Do not wait for a perfectly empty queue when a coherent release is already valuable; unrelated backlog does not block a release.

Every proposal must include:

- recommended version and SemVer rationale;
- `Highlights`: two to five most valuable user outcomes, strongest first;
- full ordered changelog, most to least interesting to users, with full issue/PR URLs;
- dependency-freshness result and any update deliberately deferred;
- exact-head CI, tests, live proof, artifacts, and release-gate state;
- remaining backlog, actual release-specific blockers, residual risk, and one exact release/hold choice.

Match repository changelog style. For a meaningful release, add or maintain a `Highlights` subsection in the target changelog section when compatible; otherwise lead the target section with the highlight bullets before the full ordered entries. Do not reorder historical released sections. A proposal never authorizes version bumps, tags, publishing, GitHub Releases, or pushes.

## Release Gate

Open issues and PRs are backlog inventory, not release blockers by default. Compute only the candidate-specific blocker set immediately before release:

```text
release blockers = items explicitly scoped to the target release
                 + active authorized work promised for the target release
                 + demonstrated regressions affecting the release candidate
```

Do not ask the owner to exempt unrelated open issues or PRs. An item blocks only when repository metadata, an owner instruction, the release plan, or concrete validation ties it to the target release. Security exposure, data loss, broken install/upgrade, and candidate regressions block when they affect the candidate even without a milestone or label.

Release only when all are true:

- the owner has explicitly requested this release or authorized release execution for the repository;
- the release-specific blocker count is zero;
- required CI is green for the exact commit and branch/tag candidate being released;
- all user-facing runtime changes in the release have required live proof, unless the owner explicitly waives that proof for the release;
- release checkout is clean, on the expected branch, and fast-forward current;
- unreleased changes justify a release and the target version follows SemVer/project convention.

Recheck release-specific blockers, the candidate diff, and CI immediately before tagging or publishing. Abort if any gate changes.

In release reporting, list actual release blockers reviewed and their resolution. Do not enumerate or request waivers for unrelated backlog.

## Release Execution

Use the repository's release docs and matching skill:

- npm packages: use `npm`;
- macOS apps: use `release-mac-app`;
- other projects: use established repo scripts/workflows.

Before release:

- reconcile changelog history with existing tags/releases;
- ensure the target changelog section starts with the strongest user-facing highlights and orders remaining entries from most to least interesting;
- default to patch for compatible fixes, maintenance, refactors, docs, CI, and small behavior improvements;
- select minor only for substantial additive functionality, a meaningful new feature set, or a new backward-compatible public API;
- never use minor merely because several fixes accumulated; major requires explicit approval;
- run full release checks and review release-only edits.

After publishing, verify the actual release:

- Git tag and GitHub Release exist;
- release notes contain the complete changelog section;
- expected artifacts/install path work;
- npm packages show version, dist-tag, tarball, integrity, and publish time;
- release body links registry/artifact/integrity and CI proof when applicable.

Then open the next patch `Unreleased` section. Commit and push the closeout only when those mutations are authorized; otherwise leave the verified local closeout ready and report the exact permission needed. After an authorized push, pull `--ff-only` and finish on clean `main`.

## Reporting

Keep one compact cross-repo ledger:

- `Active`: repo, item URL, worker, current phase.
- `Intervened`: exact risk and instruction sent.
- `Needs owner`: exact decision/access required; no vague "needs review".
- `Ignored`: exact item and owner-granted exception.
- `Vision`: durable product rule proposed or updated, with source item URL.
- `Dependencies`: actionable updates or explicit current/no-update result.
- `Release proposed`: version, highlights, ordered changelog, gates, risk, and exact release/hold choice.
- `Released`: version, tag/registry verification, closeout commit.
- `Ready next`: release-specific blockers clear, CI green, recommended patch/minor version and rationale.

For each active, decision-ready, or landed code change, include `files / +insertions / -deletions` and a low/medium/high risk estimate with one-line rationale. Summaries must be self-contained; never assume the owner opened the linked issue, PR, or worker thread.

Omit archived and owner-suppressed repositories entirely. Do not list them as ignored, blocked, stale, or available work.

Whenever mentioning an issue or PR in any owner report, decision question, worker message, or status update, print its full canonical clickable URL. Never use only a repository-local number such as `#123`; include `https://github.com/OWNER/REPO/issues/123` or `https://github.com/OWNER/REPO/pull/123`.

For `Needs owner`, use the Owner Decision Brief format. Never emit a bare URL plus `land/delete`.

Report meaningful changes, not routine polling. Maintain a heartbeat automation when the user asks to keep monitoring.
