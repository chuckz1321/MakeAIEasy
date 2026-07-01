Describe 'AgentAutoUpdate core behavior' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\scripts\AgentAutoUpdate.psm1" -Force
    }

    It 'skips a normal run after a same-day successful update' {
        $temp = Join-Path $TestDrive 'last-success.json'
        @{ date = (Get-Date).ToString('yyyy-MM-dd') } |
            ConvertTo-Json |
            Set-Content -LiteralPath $temp

        Test-ShouldRunToday -StatePath $temp | Should Be $false
    }

    It 'runs when forced even after a same-day successful update' {
        $temp = Join-Path $TestDrive 'last-success.json'
        @{ date = (Get-Date).ToString('yyyy-MM-dd') } |
            ConvertTo-Json |
            Set-Content -LiteralPath $temp

        Test-ShouldRunToday -StatePath $temp -Force | Should Be $true
    }

    It 'runs when the state file is missing' {
        $temp = Join-Path $TestDrive 'missing.json'

        Test-ShouldRunToday -StatePath $temp | Should Be $true
    }

    It 'skips a normal startup fallback before the scheduled time' {
        $temp = Join-Path $TestDrive 'missing-before-eight.json'
        $now = [datetime]'2026-07-01T07:30:00'

        Test-ShouldRunNow -StatePath $temp -NotBeforeTime '08:00' -Now $now | Should Be $false
    }

    It 'runs a startup fallback after the scheduled time' {
        $temp = Join-Path $TestDrive 'missing-after-eight.json'
        $now = [datetime]'2026-07-01T08:01:00'

        Test-ShouldRunNow -StatePath $temp -NotBeforeTime '08:00' -Now $now | Should Be $true
    }

    It 'runs when forced before the scheduled time' {
        $temp = Join-Path $TestDrive 'missing-force-before-eight.json'
        $now = [datetime]'2026-07-01T07:30:00'

        Test-ShouldRunNow -StatePath $temp -NotBeforeTime '08:00' -Now $now -Force | Should Be $true
    }

    It 'plans updates for claude, codex, and copilot' {
        $plan = Get-AgentUpdatePlan

        ($plan.Name -join ',') | Should Be 'claude,codex,copilot'
    }

    It 'builds task XML with daily, logon, and StartWhenAvailable settings' {
        [xml]$xml = New-AgentTaskXml -ScriptPath 'C:\Tools\Update-Agents.ps1' -UserId 'DOMAIN\User' -Time '08:00'

        $xml.Task.Settings.StartWhenAvailable | Should Be 'true'
        $xml.Task.Triggers.CalendarTrigger.StartBoundary | Should Match 'T08:00:00'
        $xml.Task.Triggers.LogonTrigger.UserId | Should Be 'DOMAIN\User'
    }
}
