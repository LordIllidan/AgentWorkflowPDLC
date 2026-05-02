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

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: ${Command} $($Arguments -join ' ')"
    }
}

function Enable-LocalGitCredentialsForPush {
    git config --local --unset-all "http.https://github.com/.extraheader" 2>$null
    $env:GIT_TERMINAL_PROMPT = "0"
}

function Get-AgentConfigContext {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$Purpose
    )

    $configRepo = if ($env:PDLC_AGENT_CONFIG_REPO) { $env:PDLC_AGENT_CONFIG_REPO } else { "LordIllidan/AgentWorkflowPDLC-AgentConfig" }
    $configRef = if ($env:PDLC_AGENT_CONFIG_REF) { $env:PDLC_AGENT_CONFIG_REF } else { "main" }
    $cacheParent = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { ".pdlc-agent-config-cache" }
    $cachePath = Join-Path $cacheParent "agent-config-$RunId"

    if (Test-Path -LiteralPath $cachePath) {
        Remove-Item -Recurse -Force -LiteralPath $cachePath
    }

    Invoke-Checked "gh" "repo" "clone" $configRepo $cachePath
    Invoke-Checked "git" "-C" $cachePath "checkout" $configRef

    $manifestPath = Join-Path $cachePath "agents/manifest.json"
    $workerPolicyPath = Join-Path $cachePath "worker/worker-policy.md"

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Agent config manifest was not found at $manifestPath."
    }

    $manifest = Get-Content -Raw -LiteralPath $manifestPath
    $workerPolicy = if (Test-Path -LiteralPath $workerPolicyPath) { Get-Content -Raw -LiteralPath $workerPolicyPath } else { "No worker policy file found." }
    $agentPromptFiles = Get-ChildItem -LiteralPath (Join-Path $cachePath "agents") -Recurse -Filter "agent.md" | Sort-Object FullName
    $agentPrompts = foreach ($file in $agentPromptFiles) {
        $relativePath = [System.IO.Path]::GetRelativePath($cachePath, $file.FullName)
        @"
### $relativePath

```markdown
$(Get-Content -Raw -LiteralPath $file.FullName)
```
"@
    }

    return @"
# External Agent Configuration

Repository: `$configRepo`
Ref: `$configRef`
Purpose: `$Purpose`

The worker fetched this configuration at startup. Use the manifest to select the smallest useful set of specialist agents, then apply their prompts while implementing the task.

## Worker Policy

```markdown
$workerPolicy
```

## Agent Manifest

```json
$manifest
```

## Available Agent Prompts

$($agentPrompts -join "`n")
"@
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
$agentConfigContext = Get-AgentConfigContext -RunId $RunId -Purpose "issue-coding"

$slug = ConvertTo-Slug -Value $issue.title
$branchName = "agent/claude-issue-$IssueNumber-$slug-$RunId"
$runDirectory = "pdlc-runs/issue-$IssueNumber"
$promptPath = Join-Path $runDirectory "claude-code-prompt.md"
$outputPath = Join-Path $runDirectory "claude-code-output.md"

Invoke-Checked "git" "fetch" "origin" $BaseBranch
Invoke-Checked "git" "switch" "-c" $branchName "origin/$BaseBranch"

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

Fetched agent configuration:
```markdown
$agentConfigContext
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
9. State which external agent configuration and specialist agents you used.

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

Invoke-Checked "git" "add" "."
Invoke-Checked "git" "commit" "-m" "Implement Claude Code work for issue #$IssueNumber"
Enable-LocalGitCredentialsForPush
Invoke-Checked "git" "push" "-u" "origin" $branchName

$prBody = @"
## Summary

- Relates to #$IssueNumber
- Implemented by local Claude Code worker running on a GitHub self-hosted runner.
- Worker output: ``$outputPath``
- Agent config: `$($env:PDLC_AGENT_CONFIG_REPO)`

## Human approval trail

- Analysis approval command: `/approve ai-coding`
- PR approval remains manual in GitHub.

## Verification

See the worker output and GitHub CI checks for details.
"@

$prBodyPath = ".pdlc-local-claude-pr-body.md"
Write-Utf8File -Path $prBodyPath -Content $prBody

$prUrl = gh pr create --repo $Repository --title "Claude Code implementation for issue #$IssueNumber" --body-file $prBodyPath --head $branchName --base $BaseBranch
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create pull request for branch $branchName."
}
Invoke-Checked "gh" "issue" "comment" "$IssueNumber" "--repo" $Repository "--body" "Local Claude Code worker created pull request: $prUrl"
Invoke-Checked "gh" "workflow" "run" "sample-app-ci.yml" "--repo" $Repository "--ref" $branchName

Write-Output "Created pull request: $prUrl"
