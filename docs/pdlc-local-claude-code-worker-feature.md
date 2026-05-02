# Feature: Local Claude Code Worker

## Summary

This feature prepares AgentWorkflowPDLC for a real AI coding engine running on the user's workstation. It adds a self-hosted GitHub Actions workflow that starts local Claude Code after human approval in a GitHub issue.

## User Command

```text
/approve ai-coding
```

## Files

- `.github/workflows/pdlc-claude-code-worker.yml`
- `.github/scripts/pdlc-local-claude-worker.ps1`
- `.github/workflows/pdlc-claude-review-fix-worker.yml`
- `.github/scripts/pdlc-local-claude-review-fix-worker.ps1`
- `docs/local-claude-code-worker.md`
- `docs/local-claude-review-fix-worker.md`

## Operational Model

GitHub remains the control plane and audit log. The local machine is the execution plane for AI coding. Claude Code edits the checked-out repository, while the wrapper script handles git operations and PR creation.

Review feedback is handled by a separate local worker. A human adds `/fix-review` on a PR or review comment, then Claude Code reads the PR diff and review feedback, edits the existing PR branch, and the wrapper script pushes a follow-up commit.

## License And Cost Notes

- GitHub self-hosted runner follows GitHub terms.
- Claude Code follows Anthropic terms and the user's Claude Code subscription or configured provider.
- No Anthropic API key is stored in the repository by this workflow path.
- GitHub CLI is MIT licensed.
