# AgentWorkflowPDLC

AgentWorkflowPDLC is a GitHub Issue based PDLC workflow for coordinating AI agents with manual human approval gates.

The current version is intentionally lightweight but now supports an automated issue to PR loop:

- GitHub Issue is the source of work.
- Each PDLC stage is represented by a checklist item in the issue body.
- GitHub Actions reads the checklist and comments the current workflow status.
- The analysis agent comments a proposed split for new PDLC issues.
- Humans approve analysis by commenting `/approve analysis`.
- The coding agent creates a branch, generated artifacts, and a PR.
- Humans can use `/approve ai-coding` to run the local Claude Code worker on a self-hosted Windows runner.
- Humans can use `/fix-review` on a PR to run the local Claude Code review-fix worker.
- Pull requests link back to the issue and must include generated artifacts.
- The release monitor runs after merge and can create follow-up issues.

## Workflow

```mermaid
flowchart TD
    research[Research Agent] --> issue[GitHub Issue]
    issue[GitHub Issue] --> intake[Intake]
    intake --> risk[Risk Classification]
    risk --> requirements[Requirements]
    requirements --> architecture[Architecture]
    architecture --> planning[Planning]
    planning --> coding[Coding]
    coding --> pullRequest[Draft PR]
    pullRequest --> review[Review]
    pullRequest --> qa[QA]
    pullRequest --> security[Security]
    review --> docs[Docs]
    qa --> docs
    security --> docs
    docs --> release[Release Readiness]
    release --> monitor[Release Monitor]
    monitor --> done[Done]
    monitor --> followUp[Follow-up Issue]
```

## Manual Approval Model

Manual approval is done in two ways:

- checklist approvals still document stage acceptance,
- `/approve analysis` starts the coding agent and PR creation.

The current agent workers do not run LLMs and do not call external tools. They are deterministic scripts used to prove the GitHub automation contract before replacing them with Copilot, an LLM API, or MCP-backed workers.

## Repository Structure

```text
.github/
  ISSUE_TEMPLATE/
    pdlc-task.yml
    config.yml
  scripts/
    pdlc-agent-analyze.mjs
    pdlc-agent-code.mjs
    pdlc-local-claude-worker.ps1
    pdlc-local-claude-review-fix-worker.ps1
    pdlc-issue-checklist.mjs
    pdlc-release-monitor.mjs
    pdlc-research-agent.mjs
  workflows/
    pdlc-agent-analysis.yml
    pdlc-agent-coding.yml
    pdlc-claude-code-worker.yml
    pdlc-claude-review-fix-worker.yml
    pdlc-issue-checklist.yml
    pdlc-release-monitor.yml
    pdlc-research-agent.yml
  pull_request_template.md
docs/
  automated-agent-loop.md
  agentic-pdlc-workflow.md
  github-issue-approval-workflow.md
  local-claude-code-worker.md
  local-claude-review-fix-worker.md
  pr-workflow-test-scenario.md
```

## Start

1. Create a new issue using the `PDLC Agent Task` template.
2. Fill business input in Polish.
3. Wait for the analysis agent comment.
4. Comment `/approve analysis` for the deterministic worker or `/approve ai-coding` for the local Claude Code worker.
5. Review the PR created by the coding agent.
6. Comment `/fix-review` on the PR when review feedback should be addressed by the local Claude Code worker.
7. Merge the PR after CI and human approval.
8. Check the release monitoring comment or follow-up issue.

See `docs/automated-agent-loop.md` for the automated flow details.
See `docs/local-claude-code-worker.md` for the self-hosted Claude Code worker.
See `docs/local-claude-review-fix-worker.md` for review feedback fixes.

