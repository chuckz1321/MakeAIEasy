# SkillLinker

Link a project's `.claude/skills` and `.codex/skills` directories to one
neutral skill repository:

```text
<project>/.agent-skills/skills
```

The tool works at the whole `skills` directory level. If Claude and Codex
skills differ, it prints the differences and asks which directory should become
the shared source.

## Interactive Setup

One-line remote run:

```powershell
iex (irm 'https://raw.githubusercontent.com/chuckz1321/MakeAIEasy/main/SkillLinker/install.ps1')
```

With parameters:

```powershell
$setup = [scriptblock]::Create((irm 'https://raw.githubusercontent.com/chuckz1321/MakeAIEasy/main/SkillLinker/install.ps1'))
& $setup -ProjectPath C:\aiwork\casework -DryRun
```

From any project folder:

```powershell
pwsh C:\aiwork\MyTool\MakeAIEasy\SkillLinker\Setup-AgentSkills.ps1
```

Or pass a project path:

```powershell
pwsh C:\aiwork\MyTool\MakeAIEasy\SkillLinker\Setup-AgentSkills.ps1 -ProjectPath C:\aiwork\casework
```

Preview only:

```powershell
pwsh C:\aiwork\MyTool\MakeAIEasy\SkillLinker\Setup-AgentSkills.ps1 -ProjectPath C:\aiwork\casework -DryRun
```

## Advanced Entrypoints

Compare only:

```powershell
pwsh .\SkillLinker\scripts\Compare-AgentSkills.ps1 -ProjectPath C:\aiwork\casework
```

Non-interactive link:

```powershell
pwsh .\SkillLinker\scripts\Link-AgentSkills.ps1 -ProjectPath C:\aiwork\casework -Source claude
```

## Safety

- Existing directories are moved to `.agent-skills/backups/<timestamp>-full`.
- The neutral source is staged before any existing directory is moved.
- The script refuses to operate outside the selected project root.
- Directory junctions are used on Windows.
