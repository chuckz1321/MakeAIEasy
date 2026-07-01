# Agent Auto Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish a Windows Task Scheduler based daily updater for global `claude`, `codex`, and `copilot` CLI tools.

**Architecture:** PowerShell scripts live under `scripts\`. Shared behavior lives in `scripts\AgentAutoUpdate.psm1` so Pester tests can exercise command planning, same-day state checks, and scheduled task XML generation without performing real upgrades.

**Tech Stack:** PowerShell 7 or Windows PowerShell 5.1, Windows Task Scheduler, npm, WinGet, git, GitHub CLI.

## Global Constraints

- Repository path is `C:\aiwork\MyTool\AgentAutoUpdate`.
- GitHub repository name is `AgentAutoUpdate`.
- GitHub publishing account is `chuckz1321`.
- GitHub repository visibility is private.
- Daily trigger time is 08:00 local time.
- If 08:00 is missed, the task must run when Windows can next run missed tasks.
- A login trigger must also exist as startup fallback.
- Same-day successful runs are skipped unless `-Force` is passed.
- Runtime logs and state are ignored by git.

---

### Task 1: Core Module And Tests

**Files:**
- Create: `scripts\AgentAutoUpdate.psm1`
- Create: `tests\AgentAutoUpdate.Tests.ps1`

**Interfaces:**
- Produces: `Test-ShouldRunToday([string]$StatePath, [switch]$Force) -> [bool]`
- Produces: `Test-ShouldRunNow([string]$StatePath, [switch]$Force, [string]$NotBeforeTime, [datetime]$Now) -> [bool]`
- Produces: `Get-AgentUpdatePlan() -> [object[]]`
- Produces: `New-AgentTaskXml([string]$ScriptPath, [string]$UserId, [string]$Time = '08:00') -> [xml]`

- [x] **Step 1: Write failing tests**

```powershell
Describe 'AgentAutoUpdate core behavior' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\scripts\AgentAutoUpdate.psm1" -Force
    }

    It 'skips a normal run after a same-day successful update' {
        $temp = Join-Path $TestDrive 'last-success.json'
        @{ date = (Get-Date).ToString('yyyy-MM-dd') } | ConvertTo-Json | Set-Content -LiteralPath $temp
        Test-ShouldRunToday -StatePath $temp | Should -BeFalse
    }

    It 'runs when forced even after a same-day successful update' {
        $temp = Join-Path $TestDrive 'last-success.json'
        @{ date = (Get-Date).ToString('yyyy-MM-dd') } | ConvertTo-Json | Set-Content -LiteralPath $temp
        Test-ShouldRunToday -StatePath $temp -Force | Should -BeTrue
    }

    It 'plans updates for claude, codex, and copilot' {
        $plan = Get-AgentUpdatePlan
        $plan.Name | Should -Be @('claude', 'codex', 'copilot')
    }

    It 'builds task XML with daily, logon, and StartWhenAvailable settings' {
        [xml]$xml = New-AgentTaskXml -ScriptPath 'C:\Tools\Update-Agents.ps1' -UserId 'DOMAIN\User' -Time '08:00'
        $xml.Task.Settings.StartWhenAvailable | Should -Be 'true'
        $xml.Task.Triggers.CalendarTrigger.StartBoundary | Should -Match 'T08:00:00'
        $xml.Task.Triggers.LogonTrigger.UserId | Should -Be 'DOMAIN\User'
    }
}
```

- [x] **Step 2: Run tests to verify failure**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Script .\tests"`

Expected: FAIL because `scripts\AgentAutoUpdate.psm1` does not exist yet.

- [x] **Step 3: Implement the module**

Implement the three exported functions with no real command execution.

- [x] **Step 4: Run tests to verify pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Script .\tests"`

Expected: PASS.

### Task 2: Updater And Task Scripts

**Files:**
- Create: `scripts\Update-Agents.ps1`
- Create: `scripts\Install-StartupTask.ps1`
- Create: `scripts\Uninstall-StartupTask.ps1`

**Interfaces:**
- Consumes: `Get-AgentUpdatePlan`, `Test-ShouldRunToday`, `New-AgentTaskXml`
- Produces: manual update command with `-Force` and `-WhatIf`

- [x] **Step 1: Write updater around the tested module**

`Update-Agents.ps1` imports the module, checks same-day state, writes logs, runs each planned update, and writes success state only when every tool succeeds.

- [x] **Step 2: Write install and uninstall scripts**

`Install-StartupTask.ps1` registers task XML using `Register-ScheduledTask -Xml`. `Uninstall-StartupTask.ps1` unregisters the task if present.

- [x] **Step 3: Verify syntax**

Run: `pwsh -NoProfile -Command "$files = Get-ChildItem .\scripts -Filter *.ps1; foreach ($file in $files) { $null = [scriptblock]::Create((Get-Content -Raw -LiteralPath $file.FullName)) }"`

Expected: no parser errors.

### Task 3: Docs, Git, And Publish

**Files:**
- Create: `README.md`
- Create: `.gitignore`
- Modify: `docs\superpowers\specs\2026-07-01-agent-auto-update-design.md`

**Interfaces:**
- Consumes: completed scripts.
- Produces: private GitHub repo `chuckz1321/AgentAutoUpdate`.

- [x] **Step 1: Document install and operations**

README includes install, uninstall, manual run, force run, logs, state, and schedule.

- [x] **Step 2: Verify repository**

Run: `git status --short` and inspect scope.

- [x] **Step 3: Commit and publish**

Run: `gh repo create AgentAutoUpdate --private --source . --remote origin --push`.

Expected: private repository is created under the active GitHub account `chuckz1321`.

## Self-Review

- Spec coverage: daily 08:00, missed-run behavior, login fallback, same-day skip, logs, private GitHub publish, and all three tools are covered.
- Placeholder scan: no `TBD`, `TODO`, or undefined future work remains.
- Type consistency: exported function names match across tasks.
