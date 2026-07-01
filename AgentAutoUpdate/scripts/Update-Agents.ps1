[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$WhatIf,

    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$NotBeforeTime = '08:00'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $PSScriptRoot 'AgentAutoUpdate.psm1'
$logDirectory = Join-Path $rootPath 'logs'
$stateDirectory = Join-Path $rootPath 'state'
$statePath = Join-Path $stateDirectory 'last-success.json'

Import-Module $modulePath -Force

New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null

$logPath = Join-Path $logDirectory ("agent-auto-update-{0}.log" -f (Get-Date).ToString('yyyy-MM-dd'))

function Write-AgentLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $line = '[{0}] {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Format-AgentCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $quotedArguments = foreach ($argument in $Arguments) {
        if ($argument -match '\s|["]') {
            '"{0}"' -f ($argument -replace '"', '\"')
        }
        else {
            $argument
        }
    }

    (@($Executable) + $quotedArguments) -join ' '
}

function Invoke-AgentUpdateAttempt {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Attempt
    )

    $command = Get-Command $Attempt.Executable -ErrorAction SilentlyContinue
    if (-not $command) {
        Write-AgentLog ("SKIP: {0} is not available for {1}" -f $Attempt.Executable, $Attempt.Description)
        return $false
    }

    $displayCommand = Format-AgentCommand -Executable $Attempt.Executable -Arguments $Attempt.Arguments
    Write-AgentLog ("RUN: {0} ({1})" -f $displayCommand, $Attempt.Description)

    if ($WhatIf) {
        Write-AgentLog "WHATIF: command not executed"
        return $true
    }

    $global:LASTEXITCODE = 0
    $output = & $command.Source @($Attempt.Arguments) 2>&1
    $exitCode = $LASTEXITCODE

    foreach ($line in $output) {
        Write-AgentLog ("OUT: {0}" -f $line)
    }

    if ($exitCode -eq 0) {
        Write-AgentLog ("OK: {0}" -f $Attempt.Description)
        return $true
    }

    Write-AgentLog ("FAIL: exit code {0} from {1}" -f $exitCode, $displayCommand)
    return $false
}

Write-AgentLog "Agent auto update started"

if (-not (Test-ShouldRunNow -StatePath $statePath -Force:$Force -NotBeforeTime $NotBeforeTime)) {
    Write-AgentLog ("SKIP: update is either already complete today or current time is before {0}. Use -Force to run anyway." -f $NotBeforeTime)
    exit 0
}

$failedTools = New-Object System.Collections.Generic.List[string]
$updatedTools = New-Object System.Collections.Generic.List[string]

foreach ($tool in Get-AgentUpdatePlan) {
    Write-AgentLog ("START TOOL: {0}" -f $tool.Name)
    $toolSucceeded = $false

    foreach ($attempt in $tool.Attempts) {
        if (Invoke-AgentUpdateAttempt -Attempt $attempt) {
            $toolSucceeded = $true
            break
        }
    }

    if ($toolSucceeded) {
        $updatedTools.Add($tool.Name)
        Write-AgentLog ("DONE TOOL: {0}" -f $tool.Name)
    }
    else {
        $failedTools.Add($tool.Name)
        Write-AgentLog ("FAILED TOOL: {0}" -f $tool.Name)
    }
}

if ($failedTools.Count -gt 0) {
    Write-AgentLog ("Agent auto update failed for: {0}" -f ($failedTools -join ', '))
    exit 1
}

if (-not $WhatIf) {
    [pscustomobject]@{
        date      = (Get-Date).ToString('yyyy-MM-dd')
        timestamp = (Get-Date).ToString('o')
        tools     = @($updatedTools)
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statePath -Encoding UTF8

    Write-AgentLog ("WROTE STATE: {0}" -f $statePath)
}

Write-AgentLog "Agent auto update completed successfully"
exit 0
