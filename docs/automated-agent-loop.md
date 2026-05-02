# Automated Agent Loop

## Goal

This document describes the MVP loop where GitHub Issues drive automated PDLC agent work:

1. Research agent creates or enriches feature proposal issues.
2. Analyst agent turns the issue into user stories, acceptance criteria, scope, and questions.
3. Autonomy Risk agent decides whether the feature can be implemented by an agent or should go to a human developer.
4. Architect agent defines affected areas, contracts, ADR needs, and technical boundaries.
5. Planner agent prepares the implementation handoff.
6. Human approves implementation with `/approve analysis` or `/approve ai-coding`.
7. Coding agent creates a branch, writes PDLC artifacts, updates code/docs, and opens a PR.
8. Human reviews the PR and can ask the local review-fix worker to address feedback with `/fix-review`.
9. Human merges the PR.
10. Release monitor runs after merge and creates a follow-up issue when a deployment failure signal is present.

Most GitHub events enter through `.github/workflows/pdlc-agent-router.yml`. The router decides whether to run status update, analysis, stage agent, coding, local Claude Code coding, or review-fix work.

## Step 0: Research Agent

Workflow: `.github/workflows/pdlc-research-agent.yml`

Triggers:

- weekly schedule: Monday 07:00 UTC,
- manual `workflow_dispatch` with optional `research_topic`.

Output:

- a new issue labeled `pdlc`, `agent-workflow`, and `research-proposal`,
- issue body compatible with the PDLC approval checklist,
- automatic analysis by the analysis agent after issue creation.

## Command-Driven Stage Agents

Workflow: `.github/workflows/pdlc-agent-router.yml`

Supported issue comments:

```text
/pdlc research
/pdlc analyze
/pdlc risk
/pdlc architecture
/pdlc plan
```

Each command runs local Claude Code on the self-hosted Windows runner and creates or updates a marked issue comment. These comments become PDLC artifacts consumed by the local Claude Code coding worker.

## Step 1: Analysis Agent

Workflow: `.github/workflows/pdlc-agent-router.yml`

Triggers:

- issue opened,
- issue edited,
- issue reopened,
- issue labeled.

Condition:

- issue must have `pdlc` or `agent-workflow` label,
- issue must not be a pull request.

Output:

- maintained issue comment marked as `Agent Analysis`,
- proposed split into product scope, architecture impact, implementation, verification, and release monitoring,
- approval instruction for the human reviewer.

## Human Approval

To approve analysis and start implementation, comment on the issue:

```text
/approve analysis
```

To route implementation to the local Claude Code worker running on the user's self-hosted Windows runner, comment:

```text
/approve ai-coding
```

PR approval and merge remain normal GitHub human review steps.

Recommended full staged path before local AI coding:

```text
/pdlc research
/pdlc analyze
/pdlc risk
/pdlc architecture
/pdlc plan
/approve ai-coding
```

## Step 2: Coding Agent

Workflow: `.github/workflows/pdlc-agent-router.yml`

Trigger:

- issue comment starting with `/approve analysis`.

Output:

- branch named `agent/issue-<number>-<slug>-<run-id>`,
- artifacts under `pdlc-runs/issue-<number>/`,
- update in `sample-app/docs/agent-generated-features.md`,
- pull request linked to the source issue,
- comment on the source issue with the PR URL.

The sample app documentation change intentionally triggers `Sample App CI` on the PR.

## Step 2b: Local Claude Code Worker

Workflow: `.github/workflows/pdlc-agent-router.yml`

Trigger:

- issue comment starting with `/approve ai-coding`.

Output:

- branch named `agent/claude-issue-<number>-<slug>-<run-id>`,
- Claude Code prompt and output under `pdlc-runs/issue-<number>/`,
- code changes produced by local Claude Code,
- prior PDLC stage artifacts injected into the Claude Code prompt,
- pull request linked to the source issue,
- comment on the source issue with the PR URL.

This path requires a GitHub self-hosted runner on the user's Windows workstation with the `pdlc-worker` label.

## Step 2c: Local Claude Review Fix Worker

Workflow: `.github/workflows/pdlc-agent-router.yml`

Trigger:

- PR comment, inline review comment, or submitted review containing `/fix-review`.

Output:

- Claude Code review-fix prompt and output under `pdlc-runs/pr-<number>/`,
- follow-up commit pushed to the existing PR branch,
- PR comment with the worker output path and run link,
- `Sample App CI` dispatch for the updated PR branch.

This path refuses fork PRs and does not merge or approve the PR.

## Step 3: Release Monitor

Workflow: `.github/workflows/pdlc-release-monitor.yml`

Trigger:

- PR closed and merged.

Output:

- release monitoring comment on the source issue,
- follow-up issue only when a failure signal is present.

Failure signals in the MVP:

- PR label `simulate-deployment-failure`,
- PR title or body containing `[simulate-failure]`,
- workflow environment variable `FORCE_DEPLOYMENT_FAILURE=true`.

## Current Limitations

- Stage, local coding, and review-fix routes require the self-hosted Windows runner and local Claude Code authentication.
- The release monitor does not check a real deployment endpoint yet.
- The coding agent makes a safe documentation-level sample app change.
- Role-based approval is not enforced yet; approvals are visible in GitHub audit history.

## Next Extension

Replace the deterministic scripts with a real worker that can call Copilot, an LLM API, or MCP tools, while keeping the same GitHub contract: issue in, analysis comment, human approval, PR out, release monitoring after merge.
