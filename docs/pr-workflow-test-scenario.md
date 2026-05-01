# PR Workflow Test Scenario

## Purpose

This scenario is a small change that can be used to test the AgentWorkflowPDLC pull request path without touching production code.

## Test Steps

1. Open a `PDLC Agent Task` issue.
2. Fill the business context in Polish.
3. Approve gates manually in the issue checklist up to `Planning approved`.
4. Create a branch with a documentation-only change.
5. Open a pull request using `.github/pull_request_template.md`.
6. Confirm that GitHub Actions can run and that reviewers can link the PR back to the PDLC issue.

## Expected Result

The PR should demonstrate that the repository supports a manual approval workflow before coding, while still using normal GitHub pull request review for final changes.

