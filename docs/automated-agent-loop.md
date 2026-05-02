# Automated Agent Loop

## Goal

GitHub Issues and selected commit messages drive one AI agent router. The router starts local Claude Code workers on the self-hosted Windows runner and maintains one long-lived PR per issue.

## Entry Points

New issue:

- `issues.opened` always starts autonomy risk assessment.
- The risk agent labels the issue as `pdlc-mode:developer`, `pdlc-mode:semi-auto`, or `pdlc-mode:full-auto`.
- The first agent creates the long-lived PR if it does not exist.

Issue comments:

```text
/pdlc research
/pdlc analyze
/pdlc risk
/pdlc architecture
/pdlc plan
/approve ai-coding
/pdlc answer
stage: architecture

<answers>
```

Commit messages on `main`:

```text
[PDLC #16] /pdlc analyze
[PDLC issue:16] /approve ai-coding
```

## Artifact Flow

The PR is the source of truth. Issue comments are only commands, status, and user answers.

```text
pdlc-runs/issue-<number>/00-issue.md
pdlc-runs/issue-<number>/05-autonomy-risk.md
pdlc-runs/issue-<number>/10-research.md
pdlc-runs/issue-<number>/20-analysis.md
pdlc-runs/issue-<number>/40-architecture.md
pdlc-runs/issue-<number>/50-plan.md
pdlc-runs/issue-<number>/60-implementation.md
```

## Question Gate

Agents must not continue with weak assumptions. If a stage is blocked, it writes `Status: BLOCKED_QUESTIONS`, commits the artifact to the PR, and comments on the issue with the answer format.

The user answers with `/pdlc answer`, names the blocked stage, and the same stage runs again using PR artifacts plus the answer comment as context.

## Automation Modes

- `pdlc-mode:developer` - humans implement; agents can still document context.
- `pdlc-mode:semi-auto` - humans trigger each step by comments.
- `pdlc-mode:full-auto` - each successful stage dispatches the next stage through `workflow_dispatch`.

## Current AI Workflow

Only `.github/workflows/pdlc-agent-router.yml` remains active. It routes issue events, comments, push commit commands, manual workflow dispatches, and review-fix requests to the correct local Claude Code worker.

PR approval and merge remain normal human GitHub review steps.
