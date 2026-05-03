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

. (Join-Path $PSScriptRoot 'pdlc-claude-diagnostics.ps1')

function Test-RequiredCommand {
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

    Invoke-Checked "gh" "repo" "clone" $configRepo $cachePath | Out-Null
    Invoke-Checked "git" "-C" $cachePath "checkout" $configRef | Out-Null

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

~~~markdown
$(Get-Content -Raw -LiteralPath $file.FullName)
~~~
"@
    }

    return @"
# External Agent Configuration

Repository: $configRepo
Ref: $configRef
Purpose: $Purpose

The worker fetched this configuration at startup. Use the manifest to select the smallest useful set of specialist agents, then apply their prompts while implementing the task.

## Worker Policy

~~~markdown
$workerPolicy
~~~

## Agent Manifest

~~~json
$manifest
~~~

## Available Agent Prompts

$($agentPrompts -join "`n")
"@
}

function Get-PdlcPullRequestForIssue {
    param([Parameter(Mandatory = $true)][int]$IssueNumber)

    $prs = @(gh pr list --repo $Repository --state open --limit 100 --json number,url,headRefName,title,body | ConvertFrom-Json)
    return @(
        $prs | Where-Object {
            $_.headRefName -like "agent/pdlc-issue-$IssueNumber-*" -or
            $_.title -like "*issue #$IssueNumber*" -or
            $_.body -like "*#$IssueNumber*"
        }
    ) | Select-Object -First 1
}

function Write-IssueContextFile {
    param(
        [Parameter(Mandatory = $true)]$Issue,
        [Parameter(Mandatory = $true)][string]$RunDirectory
    )

    $issuePath = Join-Path $RunDirectory "00-issue.md"
    if (Test-Path -LiteralPath $issuePath) {
        return
    }

    $content = @"
# PDLC Issue Context

Issue: #$($Issue.number) $($Issue.title)
URL: $($Issue.url)

## Body

~~~markdown
$($Issue.body)
~~~
"@

    Write-Utf8File -Path $issuePath -Content $content
}

function Get-PdlcArtifactContext {
    param([Parameter(Mandatory = $true)][string]$RunDirectory)

    if (-not (Test-Path -LiteralPath $RunDirectory)) {
        return "No PDLC artifacts exist yet."
    }

    $files = @(Get-ChildItem -LiteralPath $RunDirectory -Filter "*.md" | Sort-Object Name)
    if ($files.Count -eq 0) {
        return "No PDLC artifacts exist yet."
    }

    return (($files | ForEach-Object {
        @"
## $($_.Name)

~~~markdown
$(Get-Content -Raw -LiteralPath $_.FullName)
~~~
"@
    }) -join "`n`n---`n`n")
}

function Get-IssueCommentContext {
    param([Parameter(Mandatory = $true)][int]$IssueNumber)

    $comments = @(gh api "repos/$Repository/issues/$IssueNumber/comments?per_page=100" | ConvertFrom-Json)
    if ($comments.Count -eq 0) {
        return "No issue comments found."
    }

    return (($comments | Select-Object -Last 20 | ForEach-Object {
        "Author: $($_.user.login)`nCreated: $($_.created_at)`n`n$($_.body)"
    }) -join "`n`n---`n`n")
}

function Initialize-PdlcBranch {
    param(
        [Parameter(Mandatory = $true)]$Issue,
        [Parameter(Mandatory = $true)][string]$BaseBranch
    )

    $existingPr = Get-PdlcPullRequestForIssue -IssueNumber $Issue.number
    if ($existingPr) {
        Invoke-Checked "git" "fetch" "origin" $existingPr.headRefName | Out-Null
        Invoke-Checked "git" "switch" "-C" $existingPr.headRefName "origin/$($existingPr.headRefName)" | Out-Null

        return [pscustomobject]@{
            BranchName = $existingPr.headRefName
            PrUrl = $existingPr.url
            HasExistingPr = $true
        }
    }

    $slug = ConvertTo-Slug -Value $Issue.title
    $branchName = "agent/pdlc-issue-$($Issue.number)-$slug"

    Invoke-Checked "git" "fetch" "origin" $BaseBranch | Out-Null
    Invoke-Checked "git" "switch" "-c" $branchName "origin/$BaseBranch" | Out-Null

    return [pscustomobject]@{
        BranchName = $branchName
        PrUrl = $null
        HasExistingPr = $false
    }
}

function New-PdlcPullRequest {
    param(
        [Parameter(Mandatory = $true)]$Issue,
        [Parameter(Mandatory = $true)][string]$BranchName,
        [Parameter(Mandatory = $true)][string]$BaseBranch,
        [Parameter(Mandatory = $true)][string]$RunDirectory
    )

    $body = @"
## Summary

- Relates to #$($Issue.number)
- Long-lived PDLC pull request.
- PDLC context directory: ``$RunDirectory``

## PDLC Flow

- Autonomy risk: ``$RunDirectory/05-autonomy-risk.md``
- Research: ``$RunDirectory/10-research.md``
- Analysis: ``$RunDirectory/20-analysis.md``
- Architecture: ``$RunDirectory/40-architecture.md``
- Plan: ``$RunDirectory/50-plan.md``
- Implementation: ``$RunDirectory/60-implementation.md``

## Review

Review this PR as the single source of truth for the issue lifecycle. Issue comments are only control/status messages.
"@

    $bodyPath = ".pdlc-local-claude-pr-body.md"
    Write-Utf8File -Path $bodyPath -Content $body

    $prUrl = gh pr create --repo $Repository --title "PDLC workflow for issue #$($Issue.number)" --body-file $bodyPath --head $BranchName --base $BaseBranch
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create pull request for branch $BranchName."
    }

    return $prUrl
}

Test-RequiredCommand "git"
Test-RequiredCommand "gh"
Test-RequiredCommand "claude"

$model = if ($env:PDLC_CLAUDE_MODEL) { $env:PDLC_CLAUDE_MODEL } else { "sonnet" }
$budget = if ($env:PDLC_CLAUDE_MAX_BUDGET_USD) { $env:PDLC_CLAUDE_MAX_BUDGET_USD } else { "3" }

$issue = gh issue view $IssueNumber --repo $Repository --json number,title,body,url,labels | ConvertFrom-Json
$runDirectory = "pdlc-runs/issue-$IssueNumber"
$promptPath = Join-Path $runDirectory "claude-code-prompt.md"
$outputPath = Join-Path $runDirectory "claude-code-output.md"
$implementationPath = Join-Path $runDirectory "60-implementation.md"

$agentConfigContext = Get-AgentConfigContext -RunId $RunId -Purpose "issue-coding"
$branchContext = Initialize-PdlcBranch -Issue $issue -BaseBranch $BaseBranch
Write-IssueContextFile -Issue $issue -RunDirectory $runDirectory
$artifactContext = Get-PdlcArtifactContext -RunDirectory $runDirectory
$commentContext = Get-IssueCommentContext -IssueNumber $IssueNumber

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
- Long-lived PR branch: $($branchContext.BranchName)

PDLC artifact files from the PR branch:
~~~markdown
$artifactContext
~~~

Recent issue comments and user answers:
~~~markdown
$commentContext
~~~

Fetched agent configuration:
~~~markdown
$agentConfigContext
~~~

Task:
1. Continue the existing long-lived PDLC PR for this issue.
2. Implement the requested code change in this repository.
3. Use pdlc-runs/issue-$IssueNumber/ as the primary source of scope, risk, architecture, and implementation plan.
4. If the PR artifacts contain unresolved questions that block implementation, do not fake assumptions. Start the output with exactly: Status: BLOCKED_QUESTIONS and list questions for the user.
5. If implementation can proceed, start the output with exactly: Status: READY.
6. Keep changes scoped to the issue.
7. Add or update focused tests when the code change affects behavior.
8. Add or update documentation for the feature assumptions and example inputs.
9. Implement real code changes, not only PDLC artifacts.
10. Do not merge, do not push, and do not create a pull request. The wrapper script will commit, push, and create a PR only if one does not exist.
11. Do not read or print secrets.
12. Avoid destructive git commands.
13. Before finishing, inspect the diff and leave the workspace ready to commit.
14. State which external agent configuration and specialist agents you used.

Expected output:
- Status: READY or Status: BLOCKED_QUESTIONS.
- Changed files with purpose.
- Implemented algorithms/contracts/tests/docs.
- Verification commands you ran or intentionally skipped.
- Any remaining risks or follow-up notes.
"@

Write-Utf8File -Path $promptPath -Content $prompt

$allowedTools = "Read,Edit,Write,Glob,Grep,LS,Bash(git status:*),Bash(git diff:*),Bash(dotnet build:*),Bash(dotnet test:*),Bash(mvn test:*),Bash(npm ci:*),Bash(npm install:*),Bash(npm run build:*),Bash(npm run test:*)"
$debugPath = Join-Path $runDirectory "claude-code-debug-$RunId.log"
$claudeArgs = @(
    "--print",
    "--model", $model,
    "--permission-mode", "acceptEdits",
    "--output-format", "text",
    "--max-budget-usd", $budget,
    "--allowedTools", $allowedTools
) + (Get-PdlcClaudeDebugCliArgs $debugPath)

$claudeStartUtc = [datetime]::UtcNow
$claudeOutput = $prompt | & claude @claudeArgs 2>&1
$exitCode = $LASTEXITCODE
$claudeOutputText = ($claudeOutput | ForEach-Object { $_.ToString() }) -join "`n"

Save-PdlcClaudeSessionBundle -RunDirectory $runDirectory -WorkspacePath (Get-Location).Path -StartUtc $claudeStartUtc -RunId $RunId -Label 'coding'

$output = @"
# Claude Code Worker Output

Model: $model
Budget: $$budget
Issue: #$IssueNumber
Branch: $($branchContext.BranchName)

## Claude Output

~~~text
$claudeOutputText
~~~
"@
Write-Utf8File -Path $outputPath -Content $output

if ($exitCode -ne 0) {
    $limitHit = Test-PdlcClaudeRateLimitText $claudeOutputText
    Write-PdlcClaudeFailureToActionsLog -StreamText $claudeOutputText -ExitCode $exitCode -RateLimitSuspected:$limitHit
    $failureExcerpt = if ($claudeOutputText.Length -gt 3500) { "$($claudeOutputText.Substring(0, 3500))`n`n... truncated ..." } else { $claudeOutputText }
    $failureBody = @(
        "Claude Code worker failed before PR update.",
        "",
        "Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId",
        "",
        "Claude output excerpt:",
        "~~~text",
        $failureExcerpt,
        "~~~"
    ) -join "`n"
    gh issue comment $IssueNumber --repo $Repository --body $failureBody
    Publish-PdlcClaudeDiagnosticsGit -RunDirectory $runDirectory -BranchName $branchContext.BranchName -RunId $RunId -Kind 'coding' -AlsoAdd @($promptPath, $outputPath, $debugPath)
    throw "Claude Code exited with code $exitCode."
}

if ($claudeOutputText -match "(?im)^\s*Status\s*:\s*BLOCKED_QUESTIONS\s*$") {
    $questionBody = @"
PDLC coding worker needs user answers before implementation can continue.

PR context: $($branchContext.PrUrl)

Please answer in an issue comment and rerun coding with:

```text
/approve ai-coding

<your answers>
```

Worker questions:

```text
$claudeOutputText
```
"@
    gh issue comment $IssueNumber --repo $Repository --body $questionBody
    throw "Claude Code worker blocked on user questions."
}

$implementationArtifact = @"
# PDLC Implementation

Issue: #$IssueNumber $($issue.title)
Branch: $($branchContext.BranchName)
Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId
Model: $model

## Worker Output

~~~text
$claudeOutputText
~~~
"@
Write-Utf8File -Path $implementationPath -Content $implementationArtifact

$changes = git status --porcelain
if (-not $changes) {
    gh issue comment $IssueNumber --repo $Repository --body "Claude Code worker finished but produced no file changes. Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId"
    throw "Claude Code produced no file changes."
}

Invoke-Checked "git" "add" "."
Invoke-Checked "git" "commit" "-m" "Implement Claude Code work for issue #$IssueNumber"
Enable-LocalGitCredentialsForPush
if ($branchContext.HasExistingPr) {
    Invoke-Checked "git" "push" "origin" $branchContext.BranchName
}
else {
    Invoke-Checked "git" "push" "-u" "origin" $branchContext.BranchName
    $prUrl = New-PdlcPullRequest -Issue $issue -BranchName $branchContext.BranchName -BaseBranch $BaseBranch -RunDirectory $runDirectory
    $branchContext.PrUrl = $prUrl
}

$prInfo = if ($branchContext.PrUrl) { $branchContext.PrUrl } else { (Get-PdlcPullRequestForIssue -IssueNumber $IssueNumber).url }
Invoke-Checked "gh" "issue" "comment" "$IssueNumber" "--repo" $Repository "--body" "Local Claude Code worker updated PDLC pull request: $prInfo"

Write-Output "Updated pull request: $prInfo"
