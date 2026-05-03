# Local Claude Review Fix Worker

## Goal

This feature lets the local Claude Code worker react to pull request review feedback. The worker reads PR comments, review summaries, inline review comments, and the current diff, then pushes a follow-up commit to the same PR branch.

The worker is started manually with:

```text
/fix-review
```

## Architecture

```text
Pull Request review feedback
  -> human comment: /fix-review
  -> GitHub Actions job on self-hosted Windows runner
  -> local Claude Code CLI edits the checked-out PR branch
  -> wrapper script commits and pushes to the same branch
  -> wrapper comments on PR and dispatches Sample App CI
```

## Triggers

The workflow listens to:

- PR comments through `issue_comment`,
- inline review comments through `pull_request_review_comment`,
- submitted reviews through `pull_request_review`.

The job runs only when the matching body contains:

```text
/fix-review
```

## Components

| Component | Responsibility |
|---|---|
| `.github/workflows/pdlc-agent-router.yml` | Routes `/fix-review` events to the self-hosted Windows runner. |
| `.github/scripts/pdlc-local-claude-review-fix-worker.ps1` | Collects PR context, runs local `claude`, commits review fixes, pushes to the existing PR branch, comments on the PR, and dispatches CI. |
| GitHub self-hosted runner | Executes review fixes on the user's workstation. |
| Claude Code CLI | Interprets review feedback and edits files. |

## Safety Rules

- The worker refuses to edit fork PRs.
- The worker pushes only to the existing PR branch.
- Claude Code is instructed not to merge, push, or create PRs.
- The wrapper script performs commit and push after Claude leaves file changes.
- Manual PR approval remains required.
- CI is dispatched after the fix commit.

## Usage

1. Open a PR created by the deterministic worker or local Claude Code worker.
2. Add review feedback in PR comments or inline review comments.
3. Add a comment containing:

```text
/fix-review
```

4. Watch the `PDLC Agent Router` workflow.
5. Review the pushed follow-up commit.
6. Wait for CI and approve or request another fix.

## Claude Settings

The workflow supports repository variables:

| Variable | Default | Meaning |
|---|---:|---|
| `PDLC_CLAUDE_MODEL` | `sonnet` | Claude Code model alias or full model name. |
| `PDLC_CLAUDE_REVIEW_MAX_BUDGET_USD` | `2` | Per-run review-fix budget cap. |
| `PDLC_AGENT_CONFIG_REPO` | `LordIllidan/AgentWorkflowPDLC-AgentConfig` | Repository with external agent prompts and policies. |
| `PDLC_AGENT_CONFIG_REF` | `main` | Branch, tag, or commit used for agent configuration. |

If `PDLC_CLAUDE_REVIEW_MAX_BUDGET_USD` is not set, the script can fall back to `PDLC_CLAUDE_MAX_BUDGET_USD`.

## External Agent Configuration

Before calling Claude Code, the review-fix worker clones the configured agent repository, reads `agents/manifest.json`, and injects available specialist prompts into the review-fix prompt. The fetched manifest always includes the review agent and may also include platform specialists such as Angular, Java, .NET, or security.

See `docs/external-agent-config-repository.md`.

## Known Limitations

- This does not resolve GitHub review threads automatically.
- If Claude produces no file changes, the workflow fails and comments on the PR.
- Manually dispatched CI may not appear as a native required PR check.
- Multiple `/fix-review` comments can start multiple local jobs, so avoid parallel runs on the same PR.
- If **Claude Code** returns a **quota / plan limit** message (for example *You've hit your limit*), the worker fails without changing the branch. The workflow now posts a **PR comment** and a **Job summary** explaining that case; after reset or billing fix, run `/fix-review` again.

