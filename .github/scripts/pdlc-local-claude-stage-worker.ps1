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

function ConvertTo-MarkdownList {
    param(
        $Items,
        [Parameter(Mandatory = $true)][scriptblock]$Formatter
    )

    if ($null -eq $Items -or $Items.Count -eq 0) {
        return "No items found."
    }

    return (($Items | ForEach-Object { & $Formatter $_ }) -join "`n`n---`n`n")
}

function Get-StageDefinition {
    param([Parameter(Mandatory = $true)][string]$CommentBody)

    $normalized = $CommentBody.Trim().ToLowerInvariant()
    $stageMap = @(
        @{ Command = "/pdlc research"; Key = "research"; Marker = "<!-- pdlc-stage-research -->"; Title = "PDLC Research Agent"; AgentId = "research-agent"; NextCommand = "/pdlc analyze" },
        @{ Command = "/pdlc analyze"; Key = "analyze"; Marker = "<!-- pdlc-stage-analysis -->"; Title = "PDLC Analyst Agent"; AgentId = "analyst-agent"; NextCommand = "/pdlc risk" },
        @{ Command = "/pdlc risk"; Key = "risk"; Marker = "<!-- pdlc-stage-risk -->"; Title = "PDLC Autonomy Risk Agent"; AgentId = "risk-agent"; NextCommand = "/pdlc architecture" },
        @{ Command = "/pdlc architecture"; Key = "architecture"; Marker = "<!-- pdlc-stage-architecture -->"; Title = "PDLC Architect Agent"; AgentId = "architect-agent"; NextCommand = "/pdlc plan" },
        @{ Command = "/pdlc plan"; Key = "plan"; Marker = "<!-- pdlc-stage-plan -->"; Title = "PDLC Planner Agent"; AgentId = "planner-agent"; NextCommand = "/approve ai-coding" }
    )

    foreach ($stage in $stageMap) {
        if ($normalized.StartsWith($stage.Command)) {
            return $stage
        }
    }

    throw "No supported /pdlc stage command found in comment."
}

function Test-IsPullRequestIssue {
    param($Issue)

    if (-not $Issue) {
        return $false
    }

    return @($Issue.PSObject.Properties.Name) -contains "pull_request"
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

    Invoke-Checked "gh" "repo" "clone" $configRepo $cachePath
    Invoke-Checked "git" "-C" $cachePath "checkout" $configRef

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

function Get-PriorStageArtifacts {
    param(
        $Comments,
        [Parameter(Mandatory = $true)][string]$CurrentMarker
    )

    $artifactComments = @(
        $Comments | Where-Object {
            ($_.body -like "*<!-- pdlc-stage-*" -or $_.body -like "*<!-- pdlc-agent-analysis -->*") -and
            $_.body -notlike "*$CurrentMarker*"
        } | Sort-Object created_at
    )

    return ConvertTo-MarkdownList -Items $artifactComments -Formatter {
        param($item)
        "Author: $($item.user.login)`nCreated: $($item.created_at)`n`n$($item.body)"
    }
}

function Set-IssueComment {
    param(
        [Parameter(Mandatory = $true)][int]$IssueNumber,
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$Body
    )

    $comments = gh api "repos/$Repository/issues/$IssueNumber/comments?per_page=100" | ConvertFrom-Json
    $existing = @($comments | Where-Object { $_.body -like "*$Marker*" }) | Select-Object -First 1

    if ($existing) {
        $payload = @{ body = $Body } | ConvertTo-Json -Depth 20
        $tempPath = Join-Path $env:RUNNER_TEMP "pdlc-stage-comment-$RunId.json"
        [System.IO.File]::WriteAllText($tempPath, $payload, [System.Text.UTF8Encoding]::new($false))
        Invoke-Checked "gh" "api" "repos/$Repository/issues/comments/$($existing.id)" "--method" "PATCH" "--input" $tempPath
        return
    }

    $commentPath = Join-Path $env:RUNNER_TEMP "pdlc-stage-comment-$RunId.md"
    [System.IO.File]::WriteAllText($commentPath, $Body, [System.Text.UTF8Encoding]::new($false))
    Invoke-Checked "gh" "issue" "comment" "$IssueNumber" "--repo" $Repository "--body-file" $commentPath
}

Test-RequiredCommand "git"
Test-RequiredCommand "gh"
Test-RequiredCommand "claude"

$model = if ($env:PDLC_CLAUDE_MODEL) { $env:PDLC_CLAUDE_MODEL } else { "sonnet" }
$budget = if ($env:PDLC_CLAUDE_STAGE_MAX_BUDGET_USD) { $env:PDLC_CLAUDE_STAGE_MAX_BUDGET_USD } elseif ($env:PDLC_CLAUDE_MAX_BUDGET_USD) { $env:PDLC_CLAUDE_MAX_BUDGET_USD } else { "2" }

$eventPayload = Get-Content -Raw -LiteralPath $EventPath | ConvertFrom-Json
$issue = $eventPayload.issue
$comment = $eventPayload.comment

if (-not $issue -or (Test-IsPullRequestIssue -Issue $issue) -or -not $comment) {
    Write-Output "No normal issue comment event to process."
    exit 0
}

$stage = Get-StageDefinition -CommentBody $comment.body
$agentConfig = Get-AgentConfig -AgentId $stage.AgentId -RunId $RunId
$comments = gh api "repos/$Repository/issues/$($issue.number)/comments?per_page=100" | ConvertFrom-Json
$priorArtifacts = Get-PriorStageArtifacts -Comments $comments -CurrentMarker $stage.Marker

$prompt = @"
You are running as the $($stage.Title) inside the PDLC GitHub issue workflow.

Language policy:
- Think and reason internally in English.
- Write the final artifact in Polish because it is business-facing.
- Keep technical identifiers, commands, file paths, and agent IDs in English.

GitHub context:
- Repository: $Repository
- Issue: #$($issue.number)
- Issue URL: $($issue.html_url)
- Issue title: $($issue.title)
- Trigger command: $($stage.Command)
- Next suggested command: $($stage.NextCommand)

Issue body:
```markdown
$($issue.body)
```

Human command comment:
```markdown
$($comment.body)
```

Prior PDLC artifacts:
```markdown
$priorArtifacts
```

Agent configuration:
- Config repo: $($agentConfig.Repo)
- Config ref: $($agentConfig.Ref)
- Manifest version: $($agentConfig.ManifestVersion)
- Agent id: $($agentConfig.Agent.id)
- Agent prompt path: $($agentConfig.Agent.promptPath)

Agent base prompt:
```markdown
$($agentConfig.Prompt)
```

Task:
1. Produce a real stage artifact for this issue, not a template.
2. Use issue content, prior PDLC artifacts, and the agent base prompt.
3. If this is the research stage, provide a useful research synthesis. Use web/search tools if available in Claude Code; if not available, state that limitation and base the result on known PDLC context and repository evidence.
4. If this is the analyst stage, write concrete user stories, acceptance criteria, scope, assumptions, and questions.
5. If this is the risk stage, decide whether the feature should be agent-autonomous, agent-with-human-review, or human-dev-required.
6. If this is the architect stage, define affected areas, contracts, ADR need, security/data impact, and verification strategy.
7. If this is the planner stage, create a precise implementation handoff for the coding worker.
8. Do not edit files, do not commit, do not push, and do not create a PR.

Expected output:
- Markdown only.
- Start with a short stage summary.
- Include concrete decisions and open questions.
- End with the next command in a fenced text block.
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
    $failureBody = @"
$($stage.Marker)
## $($stage.Title) failed

Local Claude stage worker failed. Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId

~~~text
$claudeOutput
~~~
"@
    Set-IssueComment -IssueNumber $issue.number -Marker $stage.Marker -Body $failureBody
    throw "Claude Code exited with code $exitCode."
}

$body = @"
$($stage.Marker)
## $($stage.Title)

Issue: #$($issue.number) $($issue.title)

Agent runtime:
- Worker: local Claude Code on self-hosted Windows runner
- Model: `$model`
- Budget: `$budget`
- Config: `$($agentConfig.Repo)@$($agentConfig.Ref)`
- Agent: `$($agentConfig.Agent.id)`
- Run: $env:GITHUB_SERVER_URL/$Repository/actions/runs/$RunId

## Agent Output

$claudeOutput
"@

Set-IssueComment -IssueNumber $issue.number -Marker $stage.Marker -Body $body
Write-Output "Updated $($stage.Key) artifact for issue #$($issue.number)."
