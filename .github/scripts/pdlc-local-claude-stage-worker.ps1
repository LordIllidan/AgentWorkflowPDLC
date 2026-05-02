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

function Test-RequiredCommand {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$Name' was not found on PATH."
    }
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

function Enable-LocalGitCredentialsForPush {
    git config --local --unset-all "http.https://github.com/.extraheader" 2>$null
    $env:GIT_TERMINAL_PROMPT = "0"
}

function Test-IsPullRequestIssue {
    param($Issue)

    if (-not $Issue) {
        return $false
    }

    return @($Issue.PSObject.Properties.Name) -contains "pull_request"
}

function Test-ObjectProperty {
    param(
        $Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not $Object) {
        return $false
    }

    return @($Object.PSObject.Properties.Name) -contains $Name
}

function Get-StageDefinition {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [bool]$InitialRisk = $false
    )

    $normalized = $Command.Trim().ToLowerInvariant()
    $stageMap = @(
        @{ Command = "/pdlc research"; Key = "research"; FileName = "10-research.md"; Title = "PDLC Research Agent"; AgentId = "research-agent"; NextCommand = "/pdlc analyze" },
        @{ Command = "/pdlc analyze"; Key = "analysis"; FileName = "20-analysis.md"; Title = "PDLC Analyst Agent"; AgentId = "analyst-agent"; NextCommand = "/pdlc architecture" },
        @{ Command = "/pdlc risk"; Key = "risk"; FileName = "05-autonomy-risk.md"; Title = "PDLC Autonomy Risk Agent"; AgentId = "risk-agent"; NextCommand = "/pdlc research" },
        @{ Command = "/pdlc architecture"; Key = "architecture"; FileName = "40-architecture.md"; Title = "PDLC Architect Agent"; AgentId = "architect-agent"; NextCommand = "/pdlc plan" },
        @{ Command = "/pdlc plan"; Key = "plan"; FileName = "50-plan.md"; Title = "PDLC Planner Agent"; AgentId = "planner-agent"; NextCommand = "/approve ai-coding" }
    )

    foreach ($stage in $stageMap) {
        if ($normalized.StartsWith($stage.Command)) {
            return [pscustomobject]@{
                Command = $stage.Command
                Key = $stage.Key
                FileName = $stage.FileName
                Title = $stage.Title
                AgentId = $stage.AgentId
                NextCommand = $stage.NextCommand
                InitialRisk = $InitialRisk
            }
        }
    }

    throw "No supported PDLC stage command found: $Command"
}

function Get-AgentConfig {
    param(
        [Parameter(Mandatory = $true)][string]$AgentId,
        [Parameter(Mandatory = $true)][string]$RunId
    )

    $configRepo = if ($env:PDLC_AGENT_CONFIG_REPO) { $env:PDLC_AGENT_CONFIG_REPO } else { "LordIllidan/AgentWorkflowPDLC-AgentConfig" }
    $configRef = if ($env:PDLC_AGENT_CONFIG_REF) { $env:PDLC_AGENT_CONFIG_REF } else { "main" }
    $cacheParent = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { ".pdlc-agent-config-cache" }
    $cachePath = Join-Path $cacheParent "stage-agent-config-$RunId"

    if (Test-Path -LiteralPath $cachePath) {
        Remove-Item -Recurse -Force -LiteralPath $cachePath
    }

    Invoke-Checked "gh" "repo" "clone" $configRepo $cachePath | Out-Null
    Invoke-Checked "git" "-C" $cachePath "checkout" $configRef | Out-Null

    $manifestPath = Join-Path $cachePath "agents/manifest.json"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $agent = @($manifest.agents | Where-Object { $_.id -eq $AgentId }) | Select-Object -First 1

    if (-not $agent) {
        throw "Agent '$AgentId' was not found in $manifestPath."
    }

    $promptPath = Join-Path $cachePath $agent.promptPath
    $prompt = Get-Content -Raw -LiteralPath $promptPath

    return [pscustomobject]@{
        Repo = $configRepo
        Ref = $configRef
        ManifestVersion = $manifest.version
        Agent = $agent
        Prompt = $prompt
    }
}

function Get-IssueFromRepository {
    param([Parameter(Mandatory = $true)][int]$IssueNumber)

    return gh issue view $IssueNumber --repo $Repository --json number,title,body,url,labels | ConvertFrom-Json
}

function Get-StageRequest {
    param($EventPayload)

    $defaultBranch = if ((Test-ObjectProperty -Object $EventPayload -Name "repository") -and (Test-ObjectProperty -Object $EventPayload.repository -Name "default_branch")) { $EventPayload.repository.default_branch } else { "main" }

    if ($EventPayload.action -eq "pdlc_stage_command" -and (Test-ObjectProperty -Object $EventPayload -Name "client_payload")) {
        $issueNumber = [int]$EventPayload.client_payload.issue_number
        $command = [string]$EventPayload.client_payload.command
        $issue = Get-IssueFromRepository -IssueNumber $issueNumber

        return [pscustomobject]@{
            Issue = $issue
            Command = $command
            HumanComment = $command
            DefaultBranch = $defaultBranch
            InitialRisk = $false
        }
    }

    $hasIssue = Test-ObjectProperty -Object $EventPayload -Name "issue"
    $hasComment = Test-ObjectProperty -Object $EventPayload -Name "comment"

    if ($hasIssue -and -not $hasComment -and $EventPayload.action -eq "opened") {
        $issue = Get-IssueFromRepository -IssueNumber ([int]$EventPayload.issue.number)

        return [pscustomobject]@{
            Issue = $issue
            Command = "/pdlc risk"
            HumanComment = "Issue opened. Run initial autonomy risk assessment."
            DefaultBranch = $defaultBranch
            InitialRisk = $true
        }
    }

    if ($hasIssue -and $hasComment) {
        if (Test-IsPullRequestIssue -Issue $EventPayload.issue) {
            Write-Output "No normal issue comment event to process."
            exit 0
        }

        return [pscustomobject]@{
            Issue = $EventPayload.issue
            Command = $EventPayload.comment.body
            HumanComment = $EventPayload.comment.body
            DefaultBranch = $defaultBranch
            InitialRisk = $false
        }
    }

    Write-Output "No supported PDLC stage event to process."
    exit 0
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
            PrNumber = $existingPr.number
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
        PrNumber = $null
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

    $bodyPath = ".pdlc-stage-pr-body.md"
    Write-Utf8File -Path $bodyPath -Content $body

    $prUrl = gh pr create --repo $Repository --title "PDLC workflow for issue #$($Issue.number)" --body-file $bodyPath --head $BranchName --base $BaseBranch
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create PDLC pull request for branch $BranchName."
    }

    return $prUrl
}

function Initialize-AutonomyLabels {
    $labels = @(
        @{ Name = "pdlc-mode:developer"; Color = "b60205"; Description = "PDLC mode: developer-led delivery" },
        @{ Name = "pdlc-mode:semi-auto"; Color = "fbca04"; Description = "PDLC mode: comment-driven semi automation" },
        @{ Name = "pdlc-mode:full-auto"; Color = "0e8a16"; Description = "PDLC mode: full agent automation" }
    )

    foreach ($label in $labels) {
        gh label create $label.Name --repo $Repository --color $label.Color --description $label.Description 2>$null | Out-Null
    }
}

function Get-AutonomyModeFromText {
    param([Parameter(Mandatory = $true)][string]$Text)

    if ($Text -match "(?im)^\s*(mode|tryb)\s*:\s*developer\b") {
        return "developer"
    }
    if ($Text -match "(?im)^\s*(mode|tryb)\s*:\s*full[- ]?auto\b") {
        return "full-auto"
    }
    if ($Text -match "(?im)^\s*(mode|tryb)\s*:\s*semi[- ]?auto\b") {
        return "semi-auto"
    }
    if ($Text -match "(?i)full[- ]?auto") {
        return "full-auto"
    }
    if ($Text -match "(?i)\bdeveloper\b") {
        return "developer"
    }

    return "semi-auto"
}

function Get-AutonomyModeFromIssue {
    param([Parameter(Mandatory = $true)][int]$IssueNumber)

    $issue = Get-IssueFromRepository -IssueNumber $IssueNumber
    $labelNames = @($issue.labels | ForEach-Object { $_.name })
    if ($labelNames -contains "pdlc-mode:full-auto") {
        return "full-auto"
    }
    if ($labelNames -contains "pdlc-mode:developer") {
        return "developer"
    }

    return "semi-auto"
}

function Set-AutonomyModeLabel {
    param(
        [Parameter(Mandatory = $true)][int]$IssueNumber,
        [Parameter(Mandatory = $true)][string]$Mode
    )

    Initialize-AutonomyLabels
    foreach ($label in @("pdlc-mode:developer", "pdlc-mode:semi-auto", "pdlc-mode:full-auto")) {
        gh issue edit $IssueNumber --repo $Repository --remove-label $label 2>$null | Out-Null
    }

    Invoke-Checked "gh" "issue" "edit" "$IssueNumber" "--repo" $Repository "--add-label" "pdlc-mode:$Mode"
}

function Send-StageDispatch {
    param(
        [Parameter(Mandatory = $true)][int]$IssueNumber,
        [Parameter(Mandatory = $true)][string]$Command
    )

    $payload = @{
        event_type = "pdlc_stage_command"
        client_payload = @{
            issue_number = $IssueNumber
            command = $Command
        }
    } | ConvertTo-Json -Depth 10

    $payloadPath = Join-Path $env:RUNNER_TEMP "pdlc-dispatch-$RunId.json"
    [System.IO.File]::WriteAllText($payloadPath, $payload, [System.Text.UTF8Encoding]::new($false))
    Invoke-Checked "gh" "api" "repos/$Repository/dispatches" "--method" "POST" "--input" $payloadPath
}

Test-RequiredCommand "git"
Test-RequiredCommand "gh"
Test-RequiredCommand "claude"

$model = if ($env:PDLC_CLAUDE_MODEL) { $env:PDLC_CLAUDE_MODEL } else { "sonnet" }
$budget = if ($env:PDLC_CLAUDE_STAGE_MAX_BUDGET_USD) { $env:PDLC_CLAUDE_STAGE_MAX_BUDGET_USD } elseif ($env:PDLC_CLAUDE_MAX_BUDGET_USD) { $env:PDLC_CLAUDE_MAX_BUDGET_USD } else { "2" }

$eventPayload = Get-Content -Raw -LiteralPath $EventPath | ConvertFrom-Json
$request = Get-StageRequest -EventPayload $eventPayload
$stage = Get-StageDefinition -Command $request.Command -InitialRisk $request.InitialRisk
$issue = $request.Issue
$runDirectory = "pdlc-runs/issue-$($issue.number)"
$stagePath = Join-Path $runDirectory $stage.FileName

$agentConfig = Get-AgentConfig -AgentId $stage.AgentId -RunId $RunId
$branchContext = Initialize-PdlcBranch -Issue $issue -BaseBranch $request.DefaultBranch
Write-IssueContextFile -Issue $issue -RunDirectory $runDirectory
$priorArtifacts = Get-PdlcArtifactContext -RunDirectory $runDirectory

$prompt = @"
You are running as the $($stage.Title) inside the PDLC GitHub issue workflow.

Language policy:
- Think and reason internally in English.
- Write the final artifact in Polish because it is business-facing.
- Keep technical identifiers, commands, file paths, and agent IDs in English.

GitHub context:
- Repository: $Repository
- Issue: #$($issue.number)
- Issue URL: $($issue.url)
- Issue title: $($issue.title)
- Trigger command: $($stage.Command)
- Next suggested command: $($stage.NextCommand)
- Long-lived PR branch: $($branchContext.BranchName)
- Artifact file to produce: $stagePath

Issue body:
~~~markdown
$($issue.body)
~~~

Human or system command:
~~~markdown
$($request.HumanComment)
~~~

Prior PDLC artifact files from the PR branch:
~~~markdown
$priorArtifacts
~~~

Agent configuration:
- Config repo: $($agentConfig.Repo)
- Config ref: $($agentConfig.Ref)
- Manifest version: $($agentConfig.ManifestVersion)
- Agent id: $($agentConfig.Agent.id)
- Agent prompt path: $($agentConfig.Agent.promptPath)

Agent base prompt:
~~~markdown
$($agentConfig.Prompt)
~~~

Task:
1. Produce a real stage artifact for this issue, not a template.
2. Use issue content, prior PR artifact files, and the agent base prompt.
3. If this is autonomy risk assessment, choose exactly one mode and start the output with one of:
   Mode: Developer
   Mode: Semi-auto
   Mode: Full-auto
4. Developer mode means a human developer should code the task because autonomy risk is too high.
5. Semi-auto mode means humans drive the workflow by comments.
6. Full-auto mode means agents may dispatch the next PDLC command after each successful stage.
7. If this is research, provide a useful research synthesis.
8. If this is analyst stage, write concrete user stories, acceptance criteria, scope, assumptions, and questions.
9. If this is architect stage, define affected areas, contracts, ADR need, security/data impact, and verification strategy.
10. If this is planner stage, create a precise implementation handoff for the coding worker.
11. Do not edit files, do not commit, do not push, and do not create a PR. The wrapper script manages git and PR updates.

Expected output:
- Markdown only.
- Start with a short stage summary.
- Include concrete decisions and open questions.
- End with the next command in a fenced text block unless mode is Developer.
"@

$allowedTools = "Read,Glob,Grep,LS,WebSearch,WebFetch,Bash(git status:*),Bash(git diff:*)"
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

if ($exitCode -ne 0) {
    gh issue comment $issue.number --repo $Repository --body "Local Claude stage worker failed. Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId"
    throw "Claude Code exited with code $exitCode."
}

$mode = if ($stage.Key -eq "risk") { Get-AutonomyModeFromText -Text $claudeOutput } else { Get-AutonomyModeFromIssue -IssueNumber $issue.number }
if ($stage.Key -eq "risk") {
    Set-AutonomyModeLabel -IssueNumber $issue.number -Mode $mode
}

$artifact = @"
# $($stage.Title)

Issue: #$($issue.number) $($issue.title)
Branch: $($branchContext.BranchName)
Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId
Agent: $($agentConfig.Agent.id)
Model: $model
Autonomy mode: $mode

## Agent Output

$claudeOutput
"@

Write-Utf8File -Path $stagePath -Content $artifact

$changes = git status --porcelain
if ($changes) {
    Invoke-Checked "git" "add" $runDirectory
    Invoke-Checked "git" "commit" "-m" "Add $($stage.Key) PDLC artifact for issue #$($issue.number)"
    Enable-LocalGitCredentialsForPush
    if ($branchContext.HasExistingPr) {
        Invoke-Checked "git" "push" "origin" $branchContext.BranchName
    }
    else {
        Invoke-Checked "git" "push" "-u" "origin" $branchContext.BranchName
        $prUrl = New-PdlcPullRequest -Issue $issue -BranchName $branchContext.BranchName -BaseBranch $request.DefaultBranch -RunDirectory $runDirectory
        $branchContext.PrUrl = $prUrl
    }
}

$prInfo = if ($branchContext.PrUrl) { $branchContext.PrUrl } else { (Get-PdlcPullRequestForIssue -IssueNumber $issue.number).url }
$status = "PDLC stage '$($stage.Key)' updated PR context: $prInfo"
Invoke-Checked "gh" "issue" "comment" "$($issue.number)" "--repo" $Repository "--body" $status

if ($mode -eq "full-auto" -and -not [string]::IsNullOrWhiteSpace($stage.NextCommand)) {
    $nextBody = "Full-auto mode: dispatching next PDLC command `$($stage.NextCommand)` for issue #$($issue.number)."
    Invoke-Checked "gh" "issue" "comment" "$($issue.number)" "--repo" $Repository "--body" $nextBody
    Send-StageDispatch -IssueNumber $issue.number -Command $stage.NextCommand
}

Write-Output "Updated $($stage.Key) artifact for issue #$($issue.number) in $stagePath."
