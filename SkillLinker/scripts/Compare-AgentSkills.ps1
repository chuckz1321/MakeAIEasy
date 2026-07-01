[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [int]$MaxItems = 200,
    [string]$JsonReportPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SkillLinker.psm1') -Force

$comparison = Compare-AgentSkillRepositories -ProjectPath $ProjectPath
Write-Host (Format-AgentSkillComparison -Comparison $comparison -MaxItems $MaxItems)

if ($JsonReportPath) {
    $parent = Split-Path -Parent $JsonReportPath
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $comparison | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonReportPath -Encoding UTF8
    Write-Host "JSON report: $JsonReportPath"
}

if ($comparison.IsIdentical) {
    exit 0
}

exit 1
