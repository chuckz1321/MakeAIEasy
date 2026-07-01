[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,

    [ValidateSet('claude', 'codex')]
    [string]$Source,

    [switch]$DryRun,
    [int]$MaxItems = 200
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SkillLinker.psm1') -Force

$invokeParams = @{
    ProjectPath = $ProjectPath
    DryRun      = $DryRun
}

if ($PSBoundParameters.ContainsKey('Source')) {
    $invokeParams.Source = $Source
}

$result = Invoke-AgentSkillsLink @invokeParams

Write-Host (Format-AgentSkillComparison -Comparison $result.Comparison -MaxItems $MaxItems)
Write-Host ""
Write-Host "Status: $($result.Status)"
Write-Host "Target: $($result.TargetPath)"

if ($result.PSObject.Properties.Name -contains 'BackupRoot') {
    Write-Host "Backup: $($result.BackupRoot)"
}
if ($result.PSObject.Properties.Name -contains 'Source') {
    Write-Host "Source: $($result.Source) ($($result.SourcePath))"
}

if ($result.Status -eq 'DifferencesFound') {
    Write-Host ""
    Write-Host "The repositories differ. Re-run with -Source claude or -Source codex to choose the full skills source."
    exit 2
}

exit 0
