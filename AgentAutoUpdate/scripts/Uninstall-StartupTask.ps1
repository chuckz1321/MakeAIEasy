[CmdletBinding()]
param(
    [string]$TaskName = 'AgentAutoUpdate'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host ("Unregistered scheduled task '{0}'." -f $TaskName)
}
else {
    Write-Host ("Scheduled task '{0}' is not registered." -f $TaskName)
}
