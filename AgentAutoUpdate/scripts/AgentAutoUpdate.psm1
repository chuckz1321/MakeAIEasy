Set-StrictMode -Version Latest

function Test-ShouldRunToday {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StatePath,

        [switch]$Force
    )

    if ($Force) {
        return $true
    }

    if (-not (Test-Path -LiteralPath $StatePath)) {
        return $true
    }

    try {
        $state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
        $today = (Get-Date).ToString('yyyy-MM-dd')

        if ($state.date -eq $today) {
            return $false
        }
    }
    catch {
        return $true
    }

    return $true
}

function Test-ShouldRunNow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StatePath,

        [switch]$Force,

        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$NotBeforeTime = '08:00',

        [datetime]$Now = (Get-Date)
    )

    if ($Force) {
        return $true
    }

    if (-not (Test-ShouldRunToday -StatePath $StatePath)) {
        return $false
    }

    $hour, $minute = $NotBeforeTime.Split(':')
    $notBefore = $Now.Date.AddHours([int]$hour).AddMinutes([int]$minute)

    return $Now -ge $notBefore
}

function New-AgentUpdateAttempt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [string]$Description = ''
    )

    [pscustomobject]@{
        Executable  = $Executable
        Arguments   = $Arguments
        Description = $Description
    }
}

function Get-AgentUpdatePlan {
    [CmdletBinding()]
    param()

    @(
        [pscustomobject]@{
            Name     = 'claude'
            Attempts = @(
                New-AgentUpdateAttempt -Executable 'claude' -Arguments @('update') -Description 'Claude native self-update'
                New-AgentUpdateAttempt -Executable 'npm' -Arguments @('install', '-g', '@anthropic-ai/claude-code@latest') -Description 'Claude Code npm global package'
            )
        }
        [pscustomobject]@{
            Name     = 'codex'
            Attempts = @(
                New-AgentUpdateAttempt -Executable 'npm' -Arguments @('install', '-g', '@openai/codex@latest') -Description 'OpenAI Codex npm global package'
            )
        }
        [pscustomobject]@{
            Name     = 'copilot'
            Attempts = @(
                New-AgentUpdateAttempt -Executable 'winget' -Arguments @(
                    'upgrade',
                    '--id',
                    'GitHub.Copilot',
                    '--accept-source-agreements',
                    '--accept-package-agreements',
                    '--disable-interactivity'
                ) -Description 'GitHub Copilot CLI WinGet package'
            )
        }
    )
}

function New-AgentTaskXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [ValidatePattern('^\d{2}:\d{2}$')]
        [string]$Time = '08:00',

        [switch]$IncludeBootTrigger
    )

    $hour, $minute = $Time.Split(':')
    $startBoundary = (Get-Date).Date.AddHours([int]$hour).AddMinutes([int]$minute).ToString('yyyy-MM-ddTHH:mm:ss')
    $escapedUserId = [System.Security.SecurityElement]::Escape($UserId)
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $escapedArguments = [System.Security.SecurityElement]::Escape($arguments)
    $bootTriggerXml = if ($IncludeBootTrigger) {
        @"
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
"@
    }
    else {
        ''
    }

    [xml]@"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Update global claude, codex, and copilot CLI tools.</Description>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$startBoundary</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
$bootTriggerXml
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$escapedUserId</UserId>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$escapedUserId</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>pwsh.exe</Command>
      <Arguments>$escapedArguments</Arguments>
    </Exec>
  </Actions>
</Task>
"@
}

Export-ModuleMember -Function Test-ShouldRunToday, Test-ShouldRunNow, Get-AgentUpdatePlan, New-AgentTaskXml
