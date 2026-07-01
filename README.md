# AgentAutoUpdate

Windows scheduled updater for globally installed agent CLI tools:

- `claude`
- `codex`
- `copilot`

The task runs every day at 08:00. If Windows misses that time because the
machine was off or asleep, Task Scheduler is configured to start the missed
task when available. A logon trigger is also registered as a startup fallback.
The updater itself will skip normal logon-triggered runs before 08:00, so an
early login does not update before the requested time.

## Install

Run from this repository:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-StartupTask.ps1
```

This registers a scheduled task named `AgentAutoUpdate` for the current user.

## Uninstall

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Uninstall-StartupTask.ps1
```

## Manual Run

Run only if the updater has not already completed successfully today:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Update-Agents.ps1
```

Force another run today:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Update-Agents.ps1 -Force
```

Preview commands without executing upgrades:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Update-Agents.ps1 -Force -WhatIf
```

## Update Strategy

The updater detects available executables and attempts these update commands:

| Tool | Update command |
| --- | --- |
| `claude` | `claude update`, then `npm install -g @anthropic-ai/claude-code@latest` fallback |
| `codex` | `npm install -g @openai/codex@latest` |
| `copilot` | `winget upgrade --id GitHub.Copilot --accept-source-agreements --accept-package-agreements --disable-interactivity` |

Each tool is updated independently. If one tool fails, the script continues
with the remaining tools and exits with code `1` at the end.

## Logs And State

Runtime files are local and ignored by git:

- Logs: `logs\agent-auto-update-YYYY-MM-DD.log`
- Same-day success state: `state\last-success.json`

The state file is written only when all configured tool updates succeed.

## Verify

Run the core behavior tests:

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Script .\tests"
```

Check the registered task:

```powershell
Get-ScheduledTask -TaskName AgentAutoUpdate |
    Select-Object TaskName,State,@{Name='StartWhenAvailable';Expression={$_.Settings.StartWhenAvailable}},Triggers
```
