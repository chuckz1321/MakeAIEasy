[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$DryRun,
    [int]$MaxItems = 120,
    [string]$Ref = 'main'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$owner = 'chuckz1321'
$repo = 'MakeAIEasy'
$rawBase = "https://raw.githubusercontent.com/$owner/$repo/$Ref/SkillLinker"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("MakeAIEasy-SkillLinker-" + [guid]::NewGuid().ToString('N'))
$modulePath = Join-Path $tempRoot 'SkillLinker.psm1'

function Read-SourceChoice {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Comparison
    )

    Write-Host ""
    Write-Host "The two skills directories differ. Choose the full directory to use as the source:"
    Write-Host "  1. claude  ($($Comparison.ClaudePath))"
    Write-Host "  2. codex   ($($Comparison.CodexPath))"
    Write-Host "  q. quit"

    while ($true) {
        $choice = Read-Host "Select source [1/2/q]"
        switch -Regex ($choice.Trim()) {
            '^(1|claude)$' { return 'claude' }
            '^(2|codex)$' { return 'codex' }
            '^(q|quit|exit)$' { return '' }
            default { Write-Host "Please enter 1, 2, or q." }
        }
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Invoke-WebRequest -Uri "$rawBase/scripts/SkillLinker.psm1" -OutFile $modulePath -UseBasicParsing
    Import-Module $modulePath -Force

    Write-Host "Agent skills setup"
    Write-Host "Project: $ProjectPath"
    Write-Host ""

    $comparison = Compare-AgentSkillRepositories -ProjectPath $ProjectPath
    Write-Host (Format-AgentSkillComparison -Comparison $comparison -MaxItems $MaxItems)

    $source = ''
    if (-not $comparison.IsIdentical) {
        $source = Read-SourceChoice -Comparison $comparison
        if (-not $source) {
            Write-Host "No changes made."
            return
        }
    }

    $invokeParams = @{
        ProjectPath = $ProjectPath
        DryRun      = $DryRun
    }

    if ($source) {
        $invokeParams.Source = $source
    }

    $result = Invoke-AgentSkillsLink @invokeParams

    Write-Host ""
    Write-Host "Status: $($result.Status)"
    Write-Host "Target: $($result.TargetPath)"

    if ($result.PSObject.Properties.Name -contains 'BackupRoot') {
        Write-Host "Backup: $($result.BackupRoot)"
    }

    if ($result.PSObject.Properties.Name -contains 'Source') {
        Write-Host "Source: $($result.Source) ($($result.SourcePath))"
    }

    if ($DryRun) {
        Write-Host ""
        Write-Host "Dry run only. Re-run without -DryRun to apply."
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
