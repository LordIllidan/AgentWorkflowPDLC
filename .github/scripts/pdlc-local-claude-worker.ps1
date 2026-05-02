param(
    [Parameter(Mandatory = $true)]
    [int]$IssueNumber,

    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$BaseBranch,

    [Parameter(Mandatory = $true)]
    [string]$RunId
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$Name' was not found on PATH."
    }
}

function ConvertTo-Slug {
    param([Parameter(Mandatory = $true)][string]$Value)

    $slug = $Value.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")
    if ($slug.Length -gt 48) {
        $slug = $slug.Substring(0, 48).Trim("-")
    }
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "pdlc-task"
    }

    return $slug
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $fullPath = Join-Path (Resolve-Path -LiteralPath $directory).Path (Split-Path -Leaf $Path)
    }
    else {
        $fullPath = Join-Path (Get-Location).Path $Path
    }

    [System.IO.File]::WriteAllText($fullPath, $Content, [System.Text.UTF8Encoding]::new($false))
}

Require-Command "git"
Require-Command "gh"
Require-Command "claude"

$model = if ($env:PDLC_CLAUDE_MODEL) { $env:PDLC_CLAUDE_MODEL } else { "sonnet" }
$budget = if ($env:PDLC_CLAUDE_MAX_BUDGET_USD) { $env:PDLC_CLAUDE_MAX_BUDGET_USD } else { "3" }

$issue = gh issue view $IssueNumber --repo $Repository --json number,title,body,url,labels | ConvertFrom-Json
$comments = gh api "repos/$Repository/issues/$IssueNumber/comments?per_page=100" | ConvertFrom-Json
$analysisComment = $comments | Where-Object { $_.body -like "*<!-- pdlc-agent-analysis -->*" } | Select-Object -Last 1
$analysisBody = if ($analysisComment) { $analysisComment.body } else { "No prior analysis comment was found." }

$slug = ConvertTo-Slug -Value $issue.title
$branchName = "agent/claude-issue-$IssueNumber-$slug-$RunId"
$runDirectory = "pdlc-runs/issue-$IssueNumber"
$promptPath = Join-Path $runDirectory "claude-code-prompt.md"
$outputPath = Join-Path $runDirectory "claude-code-output.md"

git fetch origin $BaseBranch
git switch -c $branchName "origin/$BaseBranch"

$prompt = @"
You are the PDLC Coding Agent running locally on the user's Windows workstation through a GitHub self-hosted runner.

Language policy:
- Think and operate internally in English.
- Preserve Polish business wording when it is part of issue content or user-facing artifacts.

Source GitHub issue:
- Repository: $Repository
- Issue: #$($issue.number)
- URL: $($issue.url)
- Title: $($issue.title)

Issue body:
```markdown
$($issue.body)
```

PDLC analysis comment:
```markdown
$analysisBody
```

Task:
1. Implement the requested code change in this repository.
2. Keep changes scoped to the issue.
3. Add or update focused tests when the code change affects behavior.
4. Add or update documentation only when needed for this feature.
5. Do not merge, do not push, and do not create a pull request. The wrapper script will commit, push, and create the PR.
6. Do not read or print secrets.
7. Avoid destructive git commands.
8. Before finishing, inspect the diff and leave the workspace ready to commit.

Expected output:
- Concise summary of changed files.
- Verification commands you ran or intentionally skipped.
- Any remaining risks or follow-up notes.
"@

Write-Utf8File -Path $promptPath -Content $prompt

$allowedTools = "Read,Edit,Write,Glob,Grep,LS,Bash(git status:*),Bash(git diff:*),Bash(dotnet build:*),Bash(dotnet test:*),Bash(mvn test:*),Bash(npm install:*),Bash(npm run build:*)"
$claudeArgs = @(
    "--print",
    "--model", $model,
    "--permission-mode", "acceptEdits",
    "--output-format", "text",
    "--max-budget-usd", $budget,
    "--allowedTools", $allowedTools
)

$claudeOutput = $prompt | & claude @claudeArgs 2>&1
$exitCode = $LASTEXITCODE
$output = @"
# Claude Code Worker Output

Model: `$model`
Budget: `$$budget`
Issue: #$IssueNumber
Branch: `$branchName`

## Claude Output

```text
$claudeOutput
```
"@
Write-Utf8File -Path $outputPath -Content $output

if ($exitCode -ne 0) {
    gh issue comment $IssueNumber --repo $Repository --body "Claude Code worker failed before PR creation. Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId"
    throw "Claude Code exited with code $exitCode."
}

$changes = git status --porcelain
if (-not $changes) {
    gh issue comment $IssueNumber --repo $Repository --body "Claude Code worker finished but produced no file changes. Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId"
    throw "Claude Code produced no file changes."
}

git add .
git commit -m "Implement Claude Code work for issue #$IssueNumber"
git push -u origin $branchName

$prBody = @"
## Summary

- Relates to #$IssueNumber
- Implemented by local Claude Code worker running on a GitHub self-hosted runner.
- Worker output: `$($outputPath)`

## Human approval trail

- Analysis approval command: `/approve ai-coding`
- PR approval remains manual in GitHub.

## Verification

See the worker output and GitHub CI checks for details.
"@

$prBodyPath = ".pdlc-local-claude-pr-body.md"
Write-Utf8File -Path $prBodyPath -Content $prBody

$prUrl = gh pr create --repo $Repository --title "Claude Code implementation for issue #$IssueNumber" --body-file $prBodyPath --head $branchName --base $BaseBranch
gh issue comment $IssueNumber --repo $Repository --body "Local Claude Code worker created pull request: $prUrl"
gh workflow run sample-app-ci.yml --repo $Repository --ref $branchName

Write-Output "Created pull request: $prUrl"
