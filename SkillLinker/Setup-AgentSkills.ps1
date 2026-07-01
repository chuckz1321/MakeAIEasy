[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$DryRun,
    [int]$MaxItems = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'scripts\SkillLinker.psm1'
Import-Module $modulePath -Force

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
        exit 2
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
