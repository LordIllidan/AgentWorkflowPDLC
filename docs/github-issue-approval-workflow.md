# GitHub Issue Approval Workflow

## Purpose

This document describes the manual approval workflow implemented in GitHub Issues.

The workflow is designed for the first PDLC prototype, where humans approve each step by editing an issue checklist. It avoids secrets, LLM calls, external services, and automatic writes to product repositories.

## How To Use It

1. Open a new issue with the `PDLC Agent Task` template.
2. Fill business context in Polish.
3. Add links to repositories, documents, and related issues.
4. Let an agent or human prepare the first artifact.
5. Check the matching approval box.
6. Save the issue.
7. Wait for the `PDLC Issue Checklist` workflow to comment the current status.
8. Continue until all required gates are checked.

## Approval Checklist Contract

The workflow recognizes these checklist labels:

```text
[ ] Intake approved
[ ] Risk classification approved
[ ] Requirements approved
[ ] Architecture approved or not required
[ ] Planning approved
[ ] Coding ready for PR
[ ] Review approved
[ ] QA approved
[ ] Security approved
[ ] Documentation approved
[ ] Release readiness approved
```

The exact label text is part of the automation contract. If you rename a checkbox in the issue template, update `.github/scripts/pdlc-issue-checklist.mjs`.

## What The Action Does

The action:

- reads the issue body,
- finds known checklist items,
- determines the next incomplete stage,
- posts or updates a status comment,
- does not change checkboxes,
- does not approve anything,
- does not call an LLM,
- does not need secrets beyond `GITHUB_TOKEN`.

## What Humans Must Do

Humans must:

- review stage artifacts,
- decide whether the next step is allowed,
- check the relevant box,
- leave comments when approval is conditional,
- reject or reopen stages when artifacts are not good enough.

## Pull Request Linkage

When coding starts, the related pull request should link the PDLC issue with one of:

```text
Refs #123
Relates to #123
PDLC issue: #123
```

The PR template asks for the same stage artifacts so reviewers can follow the chain from business intent to implementation.

