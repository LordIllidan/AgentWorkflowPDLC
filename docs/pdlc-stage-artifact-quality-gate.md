# PDLC Stage Artifact Quality Gate

The stage artifact quality gate prevents a PDLC stage from committing weak context into the long-lived PR.

## Purpose

Each stage worker writes its output into `pdlc-runs/issue-<number>/`. These files are the source of truth for later agents, so the worker must reject responses that are only meta-summaries, too short, or missing required status metadata.

## Validation Rules

Before validation, the worker trims any leading preamble and keeps the artifact body from the first required `Mode:` or `Status:` line. This protects the PR from chatty model prefaces while still preserving a valid document.

The worker rejects an artifact when:

- the output is empty,
- the output looks like `artifact written`, `summary`, or another meta-response,
- a risk artifact is missing `Mode: Developer`, `Mode: Semi-auto`, or `Mode: Full-auto`,
- a non-risk stage does not start with `Status: READY` or `Status: BLOCKED_QUESTIONS`,
- the artifact is shorter than the stage minimum.

## Retry Behavior

When the first response fails validation, the worker retries once with a shorter prompt. The retry includes the issue, prior PR artifacts, stage contract, quality gate reasons, and a short excerpt of the rejected response.

If retry fails or still produces an invalid artifact, the worker comments on the issue with diagnostic details and stops the stage. It does not commit the invalid artifact to the PR.

## Operating Notes

The default stage budget is `5` USD unless `PDLC_CLAUDE_STAGE_MAX_BUDGET_USD` or `PDLC_CLAUDE_MAX_BUDGET_USD` is configured in GitHub repository variables.

