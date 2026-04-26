$Depth = 5
$Nested = $false
$Cache = $false
$CacheFile = Join-Path $env:LOCALAPPDATA "git-cd\cache"

function Write-Stderr {
    param([string]$Message)

    [Console]::Error.WriteLine($Message)
}

function Exit-WithError {
    param([string]$Message)

    Write-Stderr $Message
    exit 1
}

if (-not $env:USERPROFILE) {
    Exit-WithError "USERPROFILE environment variable is not set"
}

$configuredRoot = & git config --global --get git-cd.root 2>$null
$SearchPath = if ($configuredRoot) { $configuredRoot } else { $env:USERPROFILE }

function Show-Usage {
    Write-Host "Usage: git cd [path] [options]"
    Write-Host ""
    Write-Host "Navigate to a git repository interactively."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --depth <n>     Limit directory traversal depth (default: 5)"
    Write-Host "  --nested        Include nested repositories"
    Write-Host "  --cache         Use cached results for faster startup"
    Write-Host "  -h, --help      Show this help"
    Write-Host ""
    Write-Host "Configuration:"
    Write-Host "  git config --global git-cd.root <path>"
    Write-Host "                  Set the default search directory (overrides `$env:USERPROFILE)"
}

# Parse arguments manually to match --flag style used on macOS
$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        ''             { break }
        '--depth' {
            if ($i + 1 -ge $args.Count) { Exit-WithError "--depth requires a value" }
            $Depth = [int]$args[++$i]
            break
        }
        '--nested'     { $Nested = $true; break }
        '--cache'      { $Cache = $true; break }
        '--help'       { Show-Usage; exit 0 }
        '-h'           { Show-Usage; exit 0 }
        default {
            if ($args[$i] -notlike '--*') { $SearchPath = $args[$i] }
            else { Exit-WithError "Unknown option: $($args[$i])" }
        }
    }
    $i++
}

# When the profile's git wrapper forwards 'cd' as a positional arg and it's not a real
# directory, treat it as the subcommand name (not a path) and fall back to the default root.
if ($SearchPath -eq 'cd' -and -not (Test-Path $SearchPath -PathType Container -ErrorAction SilentlyContinue)) {
    $SearchPath = if ($configuredRoot) { $configuredRoot } else { $env:USERPROFILE }
}

if (-not (Test-Path $SearchPath -PathType Container -ErrorAction SilentlyContinue)) {
    Exit-WithError "Not a directory: $SearchPath"
}
$SearchPath = (Resolve-Path $SearchPath).Path

$SkipDirs = @('node_modules', '.git', 'AppData', '$RECYCLE.BIN', 'System Volume Information')

$SearchBlock = {
    param([string]$Root, [int]$MaxDepth, [bool]$IncludeNested, [string[]]$Skip)

    function Search([string]$Path, [int]$Depth) {
        $gitPath = Join-Path $Path '.git'
        $isRepo = Test-Path $gitPath -ErrorAction SilentlyContinue
        $isDir  = $isRepo -and (Test-Path $gitPath -PathType Container -ErrorAction SilentlyContinue)

        if ($isRepo -and ($IncludeNested -or $isDir)) {
            $Path
        }

        if ($Depth -ge $MaxDepth) { return }

        Get-ChildItem -Path $Path -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $Skip } |
            ForEach-Object { Search $_.FullName ($Depth + 1) }
    }

    Search $Root 0
}

function Find-Repos {
    & $SearchBlock $SearchPath $Depth $Nested $SkipDirs
}

# Get repo list
if ($Cache -and (Test-Path $CacheFile)) {
    $repos = Get-Content $CacheFile
} else {
    $repos = Find-Repos
    New-Item -ItemType Directory -Force -Path (Split-Path $CacheFile) | Out-Null
    $repos | Set-Content $CacheFile
}

if (-not $repos) {
    Exit-WithError "No git repositories found under $SearchPath"
}

# Select
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $selected = $repos | fzf
} else {
    $i = 1
    $repos | ForEach-Object { Write-Host "$i) $_"; $i++ }
    $num = Read-Host "Select a number"
    $selected = $repos | Select-Object -Index ([int]$num - 1)
}

if (-not $selected) { exit 1 }

Write-Output $selected
