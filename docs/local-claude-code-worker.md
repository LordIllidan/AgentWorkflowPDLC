# Local Claude Code Worker

## Goal

This feature adds the local Claude Code execution path for the PDLC workflow: the GitHub issue still controls approvals and audit, but AI work runs on the user's Windows workstation through a GitHub self-hosted runner and local Claude Code.

The deterministic coding worker remains available through `/approve analysis`. The local AI coding worker is started with:

```text
/approve ai-coding
```

## Architecture

```text
GitHub Issue
  -> PDLC Agent Analysis
  -> optional /pdlc stage commands handled by local Claude Code
  -> human comment: /approve ai-coding
  -> GitHub Actions job on self-hosted Windows runner
  -> local Claude Code CLI edits repository files
  -> wrapper script commits, pushes, opens PR, and dispatches Sample App CI
```

## Components

| Component | Responsibility |
|---|---|
| `.github/workflows/pdlc-agent-router.yml` | Routes `/pdlc ...`, `/approve ai-coding`, and `/fix-review` events to the correct worker. |
| `.github/scripts/pdlc-local-claude-stage-worker.ps1` | Builds a stage prompt, runs local `claude`, and posts the stage artifact back to the issue. |
| `.github/scripts/pdlc-local-claude-worker.ps1` | Builds the Claude prompt from the issue and analysis comment, runs local `claude`, commits changes, creates PR, and dispatches CI. |
| GitHub self-hosted runner | Executes the worker on this workstation with local tools and local Claude Code authentication. |
| Claude Code CLI | Performs code analysis and file edits. |

## Required Local Tools

The runner machine must have these commands on `PATH`:

- `git`
- `gh`
- `node`
- `claude`

The current workstation has these installed:

- Git for Windows
- GitHub CLI
- Node.js
- Claude Code CLI

## Runner Labels

The workflow requires a runner with labels:

```text
self-hosted, Windows, X64, pdlc-worker
```

The extra `pdlc-worker` label prevents arbitrary self-hosted runners from picking up coding jobs.

## Claude Settings

The workflow supports repository variables:

| Variable | Default | Meaning |
|---|---:|---|
| `PDLC_CLAUDE_MODEL` | `sonnet` | Claude Code model alias or full model name. |
| `PDLC_CLAUDE_MAX_BUDGET_USD` | `3` | Per-run Claude Code budget cap. |
| `PDLC_AGENT_CONFIG_REPO` | `LordIllidan/AgentWorkflowPDLC-AgentConfig` | Repository with external agent prompts and policies. |
| `PDLC_AGENT_CONFIG_REF` | `main` | Branch, tag, or commit used for agent configuration. |

The worker uses local Claude Code authentication already configured on the workstation. It does not require storing an Anthropic API key in GitHub for this path.

## External Agent Configuration

Before calling Claude Code, the worker clones the configured agent repository, reads `agents/manifest.json`, and injects available specialist prompts into the task prompt. Claude Code then chooses the relevant agents, for example Angular, Java, .NET, review, or security.

The worker reads prior PDLC stage artifacts from the long-lived PR branch:

```text
pdlc-runs/issue-<number>/00-issue.md
pdlc-runs/issue-<number>/05-autonomy-risk.md
pdlc-runs/issue-<number>/10-research.md
pdlc-runs/issue-<number>/20-analysis.md
pdlc-runs/issue-<number>/40-architecture.md
pdlc-runs/issue-<number>/50-plan.md
```

The implementation worker continues the same PR and writes `pdlc-runs/issue-<number>/60-implementation.md`.

See `docs/external-agent-config-repository.md`.

## Tool Permissions

Claude Code runs in non-interactive print mode with a constrained allowlist:

- file read/edit/write/search tools,
- `git status` and `git diff`,
- focused build/test commands for `.NET`, Java, and Angular.

The wrapper script, not Claude, performs:

- commit,
- push,
- PR creation,
- CI workflow dispatch.

## Usage

1. Create or open a PDLC issue.
2. Wait for `PDLC Agent Analysis`.
3. Comment:

```text
/approve ai-coding
```

4. Watch the `PDLC Agent Router` workflow.
5. Review the PR created by the local worker.
6. If review feedback should be addressed by the local worker, comment `/fix-review` on the PR.

## Security Notes

- Only use this on trusted repositories.
- The self-hosted runner can access the local machine as the runner user.
- Do not run this runner for public fork pull requests.
- Keep branch protection and manual PR approval enabled.
- Use MCP gateway authorization before granting Claude access to additional internal tools.

## Known Limitations

- This first version is designed for a single workstation and one repository.
- Parallel coding runs may compete for local CPU, disk, and Claude quota.
- If Claude produces no file changes, the workflow fails and comments on the issue.
- CI status may not appear as a native PR check when dispatched manually, but the run is linked in GitHub Actions.

## Review Feedback Loop

Review feedback is handled by a separate workflow:

- workflow: `.github/workflows/pdlc-agent-router.yml`,
- command: `/fix-review`,
- docs: `docs/local-claude-review-fix-worker.md`.

That workflow reads PR comments, review summaries, inline review comments, and the current PR diff, then pushes a follow-up commit to the same PR branch.
