# Shared helpers for Claude Code workers: CI-visible logs and on-disk session/debug bundles under pdlc-runs/.

function Get-PdlcClaudeProjectDirKey {
    param([Parameter(Mandatory = $true)][string]$AbsolutePath)
    $p = (Resolve-Path -LiteralPath $AbsolutePath).Path.TrimEnd('\')
    ($p -replace ':', '--') -replace '\\', '-'
}

function Get-PdlcClaudeDebugCliArgs {
    param([Parameter(Mandatory = $true)][string]$DebugLogPath)
    $parent = Split-Path -Parent $DebugLogPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    return @('--debug-file', $DebugLogPath)
}

function Test-PdlcClaudeRateLimitText {
    param([Parameter(Mandatory = $true)][string]$Text)
    return $Text -match '(?i)(you''ve hit your limit|hit your limit|rate limit|usage limit|billing|quota exceeded)'
}

function Write-PdlcClaudeFailureToActionsLog {
    param(
        [Parameter(Mandatory = $true)][string]$StreamText,
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $true)][bool]$RateLimitSuspected
    )

    if ($RateLimitSuspected) {
        Write-Host "::error title=PDLC Claude — limit konta / rate limit::Claude Code zwrócił limit (quota / plan). Exit $ExitCode. Pełny stdout/stderr poniżej."
    }
    else {
        Write-Host "::error title=PDLC Claude — błąd CLI::Claude Code zakończył się kodem $ExitCode. Pełny stdout/stderr poniżej."
    }

    Write-Host "========== PDLC Claude stdout/stderr (begin) =========="
    foreach ($line in ($StreamText -split "`n", [StringSplitOptions]::None)) {
        Write-Host $line
    }
    Write-Host "========== PDLC Claude stdout/stderr (end) =========="
}

function Save-PdlcClaudeSessionBundle {
    param(
        [Parameter(Mandatory = $true)][string]$RunDirectory,
        [Parameter(Mandatory = $true)][string]$WorkspacePath,
        [Parameter(Mandatory = $true)][datetime]$StartUtc,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$SubLabel = ""
    )

    $destRoot = Join-Path $RunDirectory 'claude-sessions' $RunId
    if ($SubLabel) {
        $destRoot = Join-Path $destRoot $SubLabel
    }
    New-Item -ItemType Directory -Force -Path $destRoot | Out-Null

    $readme = @(
        "# Claude Code — bundle sesji ($Label)",
        "",
        "- Run / etykieta: ``$RunId``",
        "- Workspace: ``$WorkspacePath``",
        "- Źródło kopii: ``$env:USERPROFILE\.claude\projects\`` (format katalogów Claude Code)",
        "",
        "Pliki ``*.jsonl`` to zdarzenia z przebiegu agenta (audyt / debug). Do interaktywnego wznowienia użyj ``claude --resume`` w tym samym katalogu roboczym.",
        ""
    ) -join "`n"
    Set-Content -LiteralPath (Join-Path $destRoot 'README.md') -Value $readme -Encoding utf8

    $projectsRoot = Join-Path $env:USERPROFILE '.claude' 'projects'
    if (-not (Test-Path -LiteralPath $projectsRoot)) {
        return
    }

    $resolvedWs = (Resolve-Path -LiteralPath $WorkspacePath).Path
    $key = Get-PdlcClaudeProjectDirKey -AbsolutePath $resolvedWs
    $suffix = if ($key.Length -ge 48) { $key.Substring($key.Length - 48) } else { $key }

    $dirs = @(Get-ChildItem -LiteralPath $projectsRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -eq $key -or $_.Name.Contains($suffix)
        } | Select-Object -First 12)

    $after = $StartUtc.AddSeconds(-45)
    $files = @(
        foreach ($d in $dirs) {
            Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Include '*.jsonl', '*.json' -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTimeUtc -ge $after }
        }
    ) | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 45

    $i = 0
    foreach ($f in $files) {
        $i++
        $safeName = '{0:D3}_{1}' -f $i, ($f.Name -replace '[\\/:*?"<>|]', '_')
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $destRoot $safeName) -Force -ErrorAction SilentlyContinue
    }
}

function Publish-PdlcClaudeDiagnosticsGit {
    param(
        [Parameter(Mandatory = $true)][string]$RunDirectory,
        [Parameter(Mandatory = $true)][string]$BranchName,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$Kind,
        [string[]]$AlsoAdd = @()
    )

    if ($env:PDLC_PUSH_CLAUDE_DIAGNOSTICS_ON_FAILURE -eq 'false') {
        return
    }

    if (-not (Test-Path -LiteralPath $RunDirectory)) {
        return
    }

    $sessionRoot = Join-Path $RunDirectory 'claude-sessions'
    if (Test-Path -LiteralPath $sessionRoot) {
        git add -- $sessionRoot 2>$null | Out-Null
    }

    Get-ChildItem -LiteralPath $RunDirectory -File -ErrorAction SilentlyContinue |
        Where-Object {
            $n = $_.Name
            $n -like "claude-*-debug-$RunId.log" -or
            $n -like "claude-*-debug-*$RunId*.log" -or
            $n -like "claude-stage-*-$RunId.log" -or
            $n -like "*claude-*output*$RunId*.md" -or
            $n -like "*claude-*prompt*$RunId*.md"
        } |
        ForEach-Object { git add -- $_.FullName 2>$null }

    foreach ($p in $AlsoAdd) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            git add -- $p 2>$null | Out-Null
        }
    }

    $staged = @(git diff --cached --name-only 2>$null)
    if ($staged.Count -eq 0) {
        return
    }

    git commit -m "chore(pdlc): Claude diagnostics ($Kind) run $RunId" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return
    }

    $env:GIT_TERMINAL_PROMPT = "0"
    git config --local --unset-all "http.https://github.com/.extraheader" 2>$null
    git push origin "HEAD:$BranchName" 2>$null
}

