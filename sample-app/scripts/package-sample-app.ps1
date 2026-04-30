param(
    [string] $OutputPath = ".\dist\sample-app.zip"
)

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$repoRoot = Resolve-Path (Join-Path $root "..")
$resolvedOutput = Join-Path $repoRoot $OutputPath
$outputDirectory = Split-Path $resolvedOutput -Parent
$stagingDirectory = Join-Path $env:TEMP ("agent-workflow-pdlc-sample-" + [Guid]::NewGuid().ToString("N"))

if (-not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

if (Test-Path $resolvedOutput) {
    Remove-Item $resolvedOutput -Force
}

try {
    New-Item -ItemType Directory -Path $stagingDirectory -Force | Out-Null

    $excludeDirectories = @("bin", "obj", "target", "node_modules", "dist", ".angular")
    $excludeFiles = @("*.log")

    Get-ChildItem -Path $root -Force | ForEach-Object {
        $target = Join-Path $stagingDirectory $_.Name
        if ($_.PSIsContainer) {
            Copy-Item $_.FullName $target -Recurse -Force -Exclude $excludeDirectories
        }
        else {
            Copy-Item $_.FullName $target -Force -Exclude $excludeFiles
        }
    }

    Get-ChildItem -Path $stagingDirectory -Recurse -Force -Directory |
        Where-Object { $excludeDirectories -contains $_.Name } |
        Remove-Item -Recurse -Force

    Compress-Archive -Path (Join-Path $stagingDirectory "*") -DestinationPath $resolvedOutput -Force
    Write-Output "Created ZIP package: $resolvedOutput"
}
finally {
    if (Test-Path $stagingDirectory) {
        Remove-Item $stagingDirectory -Recurse -Force
    }
}

