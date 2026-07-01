# SkillLinker

Link a project's `.claude/skills` and `.codex/skills` directories to one
neutral skill repository:

```text
<project>/.agent-skills/skills
```

The tool works at the whole `skills` directory level. If Claude and Codex
skills differ, it prints the differences and stops unless you choose a source.

## Compare

```powershell
pwsh .\SkillLinker\scripts\Compare-AgentSkills.ps1 -ProjectPath C:\aiwork\casework
```

## Link

Dry run:

```powershell
pwsh .\SkillLinker\scripts\Link-AgentSkills.ps1 -ProjectPath C:\aiwork\casework -Source claude -DryRun
```

Apply:

```powershell
pwsh .\SkillLinker\scripts\Link-AgentSkills.ps1 -ProjectPath C:\aiwork\casework -Source claude
```

If the two skill repositories are identical, `-Source` can be omitted. If they
differ, `-Source claude` or `-Source codex` is required.

## Safety

- Existing directories are moved to `.agent-skills/backups/<timestamp>-full`.
- The neutral source is staged before any existing directory is moved.
- The script refuses to operate outside the selected project root.
- Directory junctions are used on Windows.
