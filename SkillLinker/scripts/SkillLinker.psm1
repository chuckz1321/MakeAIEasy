Set-StrictMode -Version Latest

function Resolve-AgentPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    [System.IO.Path]::GetFullPath($Path)
}

function Test-PathInsideRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $root = Resolve-AgentPath $RootPath
    $candidate = Resolve-AgentPath $Path

    if (-not $root.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $root = $root + [System.IO.Path]::DirectorySeparatorChar
    }

    return $candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase) -or
        ($candidate.TrimEnd('\') -ieq $root.TrimEnd('\'))
}

function Get-AgentSkillsRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('claude', 'codex')]
        [string]$Agent
    )

    Join-Path (Resolve-AgentPath $ProjectPath) (".{0}\skills" -f $Agent)
}

function Get-AgentSkillFileMap {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillsPath
    )

    if (-not (Test-Path -LiteralPath $SkillsPath)) {
        throw "Skills path not found: $SkillsPath"
    }

    $root = (Resolve-Path -LiteralPath $SkillsPath).Path.TrimEnd('\')
    $map = @{}

    Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object {
        $relative = $_.FullName.Substring($root.Length).TrimStart('\')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        $map[$relative] = [pscustomobject]@{
            RelativePath = $relative
            Hash         = $hash
            Length       = $_.Length
            FullName     = $_.FullName
        }
    }

    return $map
}

function Compare-AgentSkillRepositories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    $project = Resolve-AgentPath $ProjectPath
    $claudePath = Get-AgentSkillsRoot -ProjectPath $project -Agent claude
    $codexPath = Get-AgentSkillsRoot -ProjectPath $project -Agent codex
    $claudeMap = Get-AgentSkillFileMap -SkillsPath $claudePath
    $codexMap = Get-AgentSkillFileMap -SkillsPath $codexPath

    $allRelativePaths = @($claudeMap.Keys + $codexMap.Keys) | Sort-Object -Unique
    $missingInCodex = New-Object System.Collections.Generic.List[string]
    $missingInClaude = New-Object System.Collections.Generic.List[string]
    $different = New-Object System.Collections.Generic.List[string]
    $sameFiles = 0

    foreach ($relativePath in $allRelativePaths) {
        if (-not $codexMap.ContainsKey($relativePath)) {
            $missingInCodex.Add($relativePath)
        }
        elseif (-not $claudeMap.ContainsKey($relativePath)) {
            $missingInClaude.Add($relativePath)
        }
        elseif ($claudeMap[$relativePath].Hash -ne $codexMap[$relativePath].Hash) {
            $different.Add($relativePath)
        }
        else {
            $sameFiles++
        }
    }

    [pscustomobject]@{
        ProjectPath     = $project
        ClaudePath      = $claudePath
        CodexPath       = $codexPath
        ClaudeFiles     = $claudeMap.Count
        CodexFiles      = $codexMap.Count
        SameFiles       = $sameFiles
        MissingInCodex  = @($missingInCodex)
        MissingInClaude = @($missingInClaude)
        Different       = @($different)
        IsIdentical     = ($missingInCodex.Count -eq 0 -and $missingInClaude.Count -eq 0 -and $different.Count -eq 0)
    }
}

function Format-AgentSkillComparison {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Comparison,

        [int]$MaxItems = 200
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Project: $($Comparison.ProjectPath)")
    $lines.Add("Claude files: $($Comparison.ClaudeFiles)")
    $lines.Add("Codex files: $($Comparison.CodexFiles)")
    $lines.Add("Same files: $($Comparison.SameFiles)")
    $lines.Add("Missing in Codex: $($Comparison.MissingInCodex.Count)")
    $lines.Add("Missing in Claude: $($Comparison.MissingInClaude.Count)")
    $lines.Add("Different: $($Comparison.Different.Count)")
    $lines.Add("Identical: $($Comparison.IsIdentical)")

    foreach ($section in @(
        @{ Name = 'Missing in Codex'; Items = $Comparison.MissingInCodex },
        @{ Name = 'Missing in Claude'; Items = $Comparison.MissingInClaude },
        @{ Name = 'Different'; Items = $Comparison.Different }
    )) {
        if ($section.Items.Count -gt 0) {
            $lines.Add("")
            $lines.Add("[$($section.Name)]")
            foreach ($item in ($section.Items | Select-Object -First $MaxItems)) {
                $lines.Add("  $item")
            }
            if ($section.Items.Count -gt $MaxItems) {
                $lines.Add("  ... $($section.Items.Count - $MaxItems) more")
            }
        }
    }

    return ($lines -join [Environment]::NewLine)
}

function Copy-AgentDirectoryMaterialized {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [hashtable]$Visited = @{}
    )

    $sourceItem = Get-Item -LiteralPath $SourcePath -Force
    $resolvedSource = if ($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint -and $sourceItem.Target) {
        Resolve-AgentPath ([string]$sourceItem.Target)
    }
    else {
        (Resolve-Path -LiteralPath $sourceItem.FullName).Path
    }

    $visitKey = $resolvedSource.ToLowerInvariant()
    if ($Visited.ContainsKey($visitKey)) {
        throw "Refusing to copy recursive linked directory: $resolvedSource"
    }
    $Visited[$visitKey] = $true

    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null

    Get-ChildItem -LiteralPath $resolvedSource -Force | ForEach-Object {
        $destination = Join-Path $DestinationPath $_.Name
        if ($_.PSIsContainer) {
            Copy-AgentDirectoryMaterialized -SourcePath $_.FullName -DestinationPath $destination -Visited $Visited
        }
        else {
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
        }
    }

    $Visited.Remove($visitKey)
}

function Test-AgentSkillsAlreadyLinked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClaudePath,

        [Parameter(Mandatory = $true)]
        [string]$CodexPath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $ClaudePath) -or -not (Test-Path -LiteralPath $CodexPath) -or -not (Test-Path -LiteralPath $TargetPath)) {
        return $false
    }

    $claude = Get-Item -LiteralPath $ClaudePath -Force
    $codex = Get-Item -LiteralPath $CodexPath -Force
    $target = (Resolve-Path -LiteralPath $TargetPath).Path

    return ($claude.LinkType -eq 'Junction' -and $codex.LinkType -eq 'Junction' -and
        ([string]$claude.Target -ieq $target) -and ([string]$codex.Target -ieq $target))
}

function Invoke-AgentSkillsLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,

        [ValidateSet('claude', 'codex')]
        [string]$Source,

        [switch]$DryRun
    )

    $project = (Resolve-Path -LiteralPath $ProjectPath).Path
    $comparison = Compare-AgentSkillRepositories -ProjectPath $project
    $claudePath = $comparison.ClaudePath
    $codexPath = $comparison.CodexPath
    $agentRoot = Join-Path $project '.agent-skills'
    $targetPath = Join-Path $agentRoot 'skills'
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupRoot = Join-Path $agentRoot "backups\$timestamp-full"
    $stagingPath = Join-Path $agentRoot "staging\skills-$timestamp"

    foreach ($path in @($claudePath, $codexPath, $agentRoot, $targetPath, $backupRoot, $stagingPath)) {
        if (-not (Test-PathInsideRoot -RootPath $project -Path $path)) {
            throw "Refusing to operate outside project root: $path"
        }
    }

    if (Test-AgentSkillsAlreadyLinked -ClaudePath $claudePath -CodexPath $codexPath -TargetPath $targetPath) {
        return [pscustomobject]@{
            Status     = 'AlreadyLinked'
            Comparison = $comparison
            TargetPath = $targetPath
        }
    }

    if (-not $comparison.IsIdentical -and -not $Source) {
        return [pscustomobject]@{
            Status     = 'DifferencesFound'
            Comparison = $comparison
            TargetPath = $targetPath
        }
    }

    $sourceAgent = if ($Source) { $Source } else { 'claude' }
    $sourcePath = if ($sourceAgent -eq 'claude') { $claudePath } else { $codexPath }

    $plan = [pscustomobject]@{
        Status     = if ($DryRun) { 'DryRun' } else { 'Linked' }
        Source     = $sourceAgent
        SourcePath = $sourcePath
        TargetPath = $targetPath
        BackupRoot = $backupRoot
        Staging    = $stagingPath
        Comparison = $comparison
    }

    if ($DryRun) {
        return $plan
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $stagingPath) -Force | Out-Null
    Copy-AgentDirectoryMaterialized -SourcePath $sourcePath -DestinationPath $stagingPath

    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    if (Test-Path -LiteralPath $targetPath) {
        Move-Item -LiteralPath $targetPath -Destination (Join-Path $backupRoot 'agent-skills-current')
    }

    Move-Item -LiteralPath $stagingPath -Destination $targetPath

    foreach ($entry in @(
        @{ Path = $claudePath; BackupName = 'claude-skills-original' },
        @{ Path = $codexPath; BackupName = 'codex-skills-original' }
    )) {
        if (Test-Path -LiteralPath $entry.Path) {
            Move-Item -LiteralPath $entry.Path -Destination (Join-Path $backupRoot $entry.BackupName)
        }
        New-Item -ItemType Junction -Path $entry.Path -Target $targetPath | Out-Null
    }

    return $plan
}

Export-ModuleMember -Function Compare-AgentSkillRepositories, Format-AgentSkillComparison, Invoke-AgentSkillsLink, Test-PathInsideRoot
