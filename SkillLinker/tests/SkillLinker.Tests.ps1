Describe 'SkillLinker comparison' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\scripts\SkillLinker.psm1" -Force
    }

    function New-SkillFile {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$Content
        )

        $parent = Split-Path -Parent $Path
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
    }

    It 'reports identical skill repositories' {
        $project = Join-Path $TestDrive 'identical'
        New-SkillFile -Path (Join-Path $project '.claude\skills\a\SKILL.md') -Content 'same'
        New-SkillFile -Path (Join-Path $project '.codex\skills\a\SKILL.md') -Content 'same'

        $result = Compare-AgentSkillRepositories -ProjectPath $project

        $result.IsIdentical | Should Be $true
        $result.SameFiles | Should Be 1
        $result.MissingInCodex.Count | Should Be 0
        $result.MissingInClaude.Count | Should Be 0
        $result.Different.Count | Should Be 0
    }

    It 'reports files missing on either side and changed content' {
        $project = Join-Path $TestDrive 'different'
        New-SkillFile -Path (Join-Path $project '.claude\skills\a\SKILL.md') -Content 'same'
        New-SkillFile -Path (Join-Path $project '.codex\skills\a\SKILL.md') -Content 'same'
        New-SkillFile -Path (Join-Path $project '.claude\skills\claude-only\SKILL.md') -Content 'claude'
        New-SkillFile -Path (Join-Path $project '.codex\skills\codex-only\SKILL.md') -Content 'codex'
        New-SkillFile -Path (Join-Path $project '.claude\skills\changed\SKILL.md') -Content 'left'
        New-SkillFile -Path (Join-Path $project '.codex\skills\changed\SKILL.md') -Content 'right'

        $result = Compare-AgentSkillRepositories -ProjectPath $project

        $result.IsIdentical | Should Be $false
        $result.SameFiles | Should Be 1
        $result.MissingInCodex | Should Be @('claude-only\SKILL.md')
        $result.MissingInClaude | Should Be @('codex-only\SKILL.md')
        $result.Different | Should Be @('changed\SKILL.md')
    }

    It 'recognizes paths inside the selected project root' {
        $project = Join-Path $TestDrive 'root'
        New-Item -ItemType Directory -Path $project -Force | Out-Null
        $inside = Join-Path $project '.agent-skills'

        Test-PathInsideRoot -RootPath $project -Path $inside | Should Be $true
    }

    It 'reports already linked repositories without modifying them' {
        $project = Join-Path $TestDrive 'linked'
        $target = Join-Path $project '.agent-skills\skills'
        New-SkillFile -Path (Join-Path $target 'a\SKILL.md') -Content 'same'
        New-Item -ItemType Directory -Path (Join-Path $project '.claude') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $project '.codex') -Force | Out-Null
        New-Item -ItemType Junction -Path (Join-Path $project '.claude\skills') -Target $target | Out-Null
        New-Item -ItemType Junction -Path (Join-Path $project '.codex\skills') -Target $target | Out-Null

        $result = Invoke-AgentSkillsLink -ProjectPath $project

        $result.Status | Should Be 'AlreadyLinked'
        $result.TargetPath | Should Be $target
    }
}
