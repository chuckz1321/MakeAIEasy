[CmdletBinding()]
param(
    [string]$TaskName = 'AgentAutoUpdate',

    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$Time = '08:00'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'AgentAutoUpdate.psm1'
$updateScriptPath = Join-Path $PSScriptRoot 'Update-Agents.ps1'
$userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Import-Module $modulePath -Force

if (-not (Test-Path -LiteralPath $updateScriptPath)) {
    throw "Update script not found: $updateScriptPath"
}

$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$taskXml = New-AgentTaskXml -ScriptPath $updateScriptPath -UserId $userId -Time $Time
Register-ScheduledTask -TaskName $TaskName -Xml $taskXml.OuterXml | Out-Null

Write-Host ("Registered scheduled task '{0}' for {1} with daily trigger at {2} and logon fallback." -f $TaskName, $userId, $Time)
