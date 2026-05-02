param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$EventPath,

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

function Get-EventPullRequestNumber {
    param([Parameter(Mandatory = $true)]$Event)

    if ($Event.issue -and $Event.issue.pull_request) {
        return [int]$Event.issue.number
    }

    if ($Event.pull_request) {
        return [int]$Event.pull_request.number
    }

    throw "Could not determine pull request number from event payload."
}

function ConvertTo-MarkdownList {
    param(
        [Parameter(Mandatory = $true)]$Items,
        [Parameter(Mandatory = $true)][scriptblock]$Formatter
    )

    if (-not $Items -or $Items.Count -eq 0) {
        return "No items found."
    }

    return (($Items | ForEach-Object { & $Formatter $_ }) -join "`n`n---`n`n")
}

Require-Command "git"
Require-Command "gh"
Require-Command "claude"

$model = if ($env:PDLC_CLAUDE_MODEL) { $env:PDLC_CLAUDE_MODEL } else { "sonnet" }
$budget = if ($env:PDLC_CLAUDE_REVIEW_MAX_BUDGET_USD) { $env:PDLC_CLAUDE_REVIEW_MAX_BUDGET_USD } elseif ($env:PDLC_CLAUDE_MAX_BUDGET_USD) { $env:PDLC_CLAUDE_MAX_BUDGET_USD } else { "2" }

$event = Get-Content -Raw -LiteralPath $EventPath | ConvertFrom-Json
$prNumber = Get-EventPullRequestNumber -Event $event
$pr = gh pr view $prNumber --repo $Repository --json number,title,body,url,headRefName,baseRefName,headRepository,headRepositoryOwner,author | ConvertFrom-Json

if ($pr.headRepository.nameWithOwner -ne $Repository) {
    throw "Refusing to modify PR #$prNumber because its head repository is '$($pr.headRepository.nameWithOwner)', not '$Repository'."
}

$issueComments = gh api "repos/$Repository/issues/$prNumber/comments?per_page=100" | ConvertFrom-Json
$reviewComments = gh api "repos/$Repository/pulls/$prNumber/comments?per_page=100" | ConvertFrom-Json
$reviews = gh api "repos/$Repository/pulls/$prNumber/reviews?per_page=100" | ConvertFrom-Json
$diff = gh pr diff $prNumber --repo $Repository

$issueCommentText = ConvertTo-MarkdownList -Items $issueComments -Formatter {
    param($item)
    "Author: $($item.user.login)`nCreated: $($item.created_at)`n`n$($item.body)"
}

$reviewCommentText = ConvertTo-MarkdownList -Items $reviewComments -Formatter {
    param($item)
    "Author: $($item.user.login)`nFile: $($item.path)`nLine: $($item.line)`nOriginal line: $($item.original_line)`nCreated: $($item.created_at)`n`n$($item.body)"
}

$reviewText = ConvertTo-MarkdownList -Items $reviews -Formatter {
    param($item)
    "Author: $($item.user.login)`nState: $($item.state)`nSubmitted: $($item.submitted_at)`n`n$($item.body)"
}

$runDirectory = "pdlc-runs/pr-$prNumber"
$promptPath = Join-Path $runDirectory "claude-review-fix-prompt-$RunId.md"
$outputPath = Join-Path $runDirectory "claude-review-fix-output-$RunId.md"

git fetch origin $($pr.baseRefName)
git fetch origin "$($pr.headRefName):refs/remotes/origin/$($pr.headRefName)"
git switch -C $($pr.headRefName) "origin/$($pr.headRefName)"

$prompt = @"
You are the PDLC Review Fix Agent running locally on the user's Windows workstation through a GitHub self-hosted runner.

Language policy:
- Think and operate internally in English.
- Preserve Polish business wording when it is part of user-facing artifacts.

Pull request:
- Repository: $Repository
- PR: #$($pr.number)
- URL: $($pr.url)
- Title: $($pr.title)
- Branch: $($pr.headRefName)
- Base: $($pr.baseRefName)

PR body:
```markdown
$($pr.body)
```

Issue and PR comments:
```markdown
$issueCommentText
```

Review summaries:
```markdown
$reviewText
```

Inline review comments:
```markdown
$reviewCommentText
```

Current PR diff:
```diff
$diff
```

Task:
1. Address the actionable review feedback for this pull request.
2. Prioritize comments near `/fix-review`, inline review comments, and CHANGES_REQUESTED review summaries.
3. Keep changes scoped to this PR and its review feedback.
4. Add or update focused tests only when needed for the review fix.
5. Do not merge, do not push, and do not create a pull request. The wrapper script will commit and push to the existing PR branch.
6. Do not read or print secrets.
7. Avoid destructive git commands.
8. Before finishing, inspect the diff and leave the workspace ready to commit.

Expected output:
- Concise summary of review feedback addressed.
- Files changed.
- Verification commands you ran or intentionally skipped.
- Any remaining review comments you could not address.
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
# Claude Review Fix Worker Output

Model: `$model`
Budget: `$$budget`
PR: #$prNumber
Branch: `$($pr.headRefName)`

## Claude Output

```text
$claudeOutput
```
"@
Write-Utf8File -Path $outputPath -Content $output

if ($exitCode -ne 0) {
    gh pr comment $prNumber --repo $Repository --body "Local Claude review-fix worker failed before pushing changes. Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId"
    throw "Claude Code exited with code $exitCode."
}

$changes = git status --porcelain
if (-not $changes) {
    gh pr comment $prNumber --repo $Repository --body "Local Claude review-fix worker finished but produced no file changes. Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId"
    throw "Claude Code produced no file changes."
}

git add .
git commit -m "Address Claude review feedback on PR #$prNumber"
git push origin "HEAD:$($pr.headRefName)"

$commentBody = @"
Local Claude review-fix worker pushed changes to this PR.

- Worker output: `$outputPath`
- Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId
- CI dispatch: `sample-app-ci.yml`
"@

gh pr comment $prNumber --repo $Repository --body $commentBody
gh workflow run sample-app-ci.yml --repo $Repository --ref $($pr.headRefName)

Write-Output "Pushed review fixes to PR #$prNumber."
