# Agent Auto Update Design

## Goal

Create a Windows startup-safe updater for globally installed agent CLI tools:
`claude`, `codex`, and `copilot`.

The repository lives at `C:\aiwork\MyTool\AgentAutoUpdate` and is published as
a private GitHub repository named `AgentAutoUpdate` under the GitHub account
`chuckz1321`.

## Scheduling

The updater runs from Windows Task Scheduler.

- Primary trigger: every day at 08:00 local time.
- Missed-run behavior: if the machine is off or asleep at 08:00, the task is
  allowed to run as soon as Windows can run missed scheduled tasks.
- Login fallback: the task also runs at user logon.
- Duplicate control: the update script keeps a per-day state file and skips
  normal runs after the first successful same-day execution. A manual force
  flag bypasses this skip.

This gives the requested behavior: run every morning at 08:00, and if the
machine was not started at 08:00, run when it starts or the user logs in.

## Components

### `scripts\Update-Agents.ps1`

Updates the configured CLI tools and writes logs.

Responsibilities:

- Detect whether update commands are available before running them.
- Update `codex` through npm using `npm install -g @openai/codex@latest`.
- Update `copilot` through WinGet using `winget upgrade --id GitHub.Copilot`.
- Update `claude` through its own command first, then npm fallback for
  `@anthropic-ai/claude-code` if npm is available.
- Log start, end, tool output, and failures.
- Return non-zero if any tool update fails.
- Maintain `state\last-success.json` for same-day skip behavior.

### `scripts\Install-StartupTask.ps1`

Registers or replaces the Windows scheduled task.

Responsibilities:

- Register the task name `AgentAutoUpdate`.
- Run PowerShell with execution policy bypass for this script only.
- Add a daily 08:00 trigger.
- Add an at-logon trigger.
- Set `StartWhenAvailable = true`.
- Run only for the current user and without storing a password.

### `scripts\Uninstall-StartupTask.ps1`

Removes the Windows scheduled task if present.

### `README.md`

Documents install, uninstall, manual run, force run, logs, and schedule.

## Data And Logs

- Logs live under `logs\agent-auto-update-YYYY-MM-DD.log`.
- State lives under `state\last-success.json`.
- Both directories are local runtime output and are ignored by git.

## Error Handling

Each tool is updated independently. A failure in one tool is logged and does
not stop the remaining tools from updating. The script exits with code `1` if
any tool failed, otherwise `0`.

The same-day state file is updated only when all configured updates succeed.

## Verification

Verification covers:

- PowerShell syntax parsing for each script.
- Manual dry run support.
- Manual force run support.
- Scheduled task registration command shape.
- Git repository initialization and publish to GitHub.
