# Automated Agent Loop

## Goal

This document describes the MVP loop where GitHub Issues drive automated PDLC agent work:

1. Research agent creates new feature proposal issues.
2. Analysis agent reads a PDLC issue, splits the change, and posts an analysis comment.
3. Human approves the analysis with `/approve analysis`.
4. Coding agent creates a branch, writes PDLC artifacts, updates the sample app documentation, and opens a PR.
5. Human reviews the PR and can ask the local review-fix worker to address feedback with `/fix-review`.
6. Human merges the PR.
7. Release monitor runs after merge and creates a follow-up issue when a deployment failure signal is present.

The current implementation is deterministic and does not call an LLM. This keeps the workflow testable before adding Copilot, an LLM API, or MCP tools.

## Step 0: Research Agent

Workflow: `.github/workflows/pdlc-research-agent.yml`

Triggers:

- weekly schedule: Monday 07:00 UTC,
- manual `workflow_dispatch` with optional `research_topic`.

Output:

- a new issue labeled `pdlc`, `agent-workflow`, and `research-proposal`,
- issue body compatible with the PDLC approval checklist,
- automatic analysis by the analysis agent after issue creation.

## Step 1: Analysis Agent

Workflow: `.github/workflows/pdlc-agent-analysis.yml`

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

## Step 2: Coding Agent

Workflow: `.github/workflows/pdlc-agent-coding.yml`

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

Workflow: `.github/workflows/pdlc-claude-code-worker.yml`

Trigger:

- issue comment starting with `/approve ai-coding`.

Output:

- branch named `agent/claude-issue-<number>-<slug>-<run-id>`,
- Claude Code prompt and output under `pdlc-runs/issue-<number>/`,
- code changes produced by local Claude Code,
- pull request linked to the source issue,
- comment on the source issue with the PR URL.

This path requires a GitHub self-hosted runner on the user's Windows workstation with the `pdlc-worker` label.

## Step 2c: Local Claude Review Fix Worker

Workflow: `.github/workflows/pdlc-claude-review-fix-worker.yml`

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

- The agents are deterministic scripts, not LLM agents.
- The release monitor does not check a real deployment endpoint yet.
- The coding agent makes a safe documentation-level sample app change.
- Role-based approval is not enforced yet; approvals are visible in GitHub audit history.

## Next Extension

Replace the deterministic scripts with a real worker that can call Copilot, an LLM API, or MCP tools, while keeping the same GitHub contract: issue in, analysis comment, human approval, PR out, release monitoring after merge.
