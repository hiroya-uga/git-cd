$ErrorActionPreference = 'Stop'

$InstallDir = Join-Path $env:USERPROFILE "bin"
$ScriptDir = if ($PSScriptRoot) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $null
}
$HasLocalScripts = $ScriptDir -and
    (Test-Path (Join-Path $ScriptDir "bin\git-cd.ps1")) -and
    (Test-Path (Join-Path $ScriptDir "bin\git-cd.cmd"))

$InstallDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$ShellFunction = @'

# git-cd BEGIN
function git {
    if ($args[0] -eq 'cd') {
        $rest = @(if ($args.Length -gt 1) { $args[1..($args.Length - 1)] } else { @() })
        $dir = & git-cd @rest
        if ($dir) { Set-Location $dir }
    } else {
        & (Get-Command git -CommandType Application) @args
    }
}
# git-cd END
'@
$ShellFunction = $ShellFunction -replace '# git-cd BEGIN', "# git-cd BEGIN`n# Installed: $InstallDate"

# Place git-cd.ps1
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

if ($HasLocalScripts) {
    # Clone install: copy scripts
    Copy-Item (Join-Path $ScriptDir "bin\git-cd.ps1") (Join-Path $InstallDir "git-cd.ps1") -Force
    Copy-Item (Join-Path $ScriptDir "bin\git-cd.cmd") (Join-Path $InstallDir "git-cd.cmd") -Force
    Write-Host "Copied: $InstallDir\git-cd.ps1"
    Write-Host "Copied: $InstallDir\git-cd.cmd"
} else {
    # Quick install: download from GitHub Releases
    Invoke-WebRequest -Uri "https://github.com/hiroya-uga/git-cd/releases/latest/download/git-cd.ps1" `
        -OutFile (Join-Path $InstallDir "git-cd.ps1")
    Invoke-WebRequest -Uri "https://github.com/hiroya-uga/git-cd/releases/latest/download/git-cd.cmd" `
        -OutFile (Join-Path $InstallDir "git-cd.cmd")
    Write-Host "Downloaded: $InstallDir\git-cd.ps1"
    Write-Host "Downloaded: $InstallDir\git-cd.cmd"
}

# Add InstallDir to PATH if not present
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$InstallDir*") {
    $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $InstallDir } else { "$userPath;$InstallDir" }
    [Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
    Write-Host "Added $InstallDir to PATH"
}

# Append shell function to PowerShell profile if not already present
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $PROFILE) | Out-Null
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Force -Path $PROFILE | Out-Null
}

$profileContent = [string](Get-Content $PROFILE -Raw)
if ($profileContent -notlike "*# git-cd BEGIN*") {
    Add-Content $PROFILE $ShellFunction
    Write-Host "Added shell function to $PROFILE"
} else {
    $updated = [regex]::Replace($profileContent, '(?s)# git-cd BEGIN.*?# git-cd END', $ShellFunction.Trim())
    Set-Content $PROFILE $updated -NoNewline
    Write-Host "Updated shell function in $PROFILE"
}

Write-Host ""
Write-Host "[ Done! ]"
Write-Host "Open a new terminal to start using 'git cd'."
Write-Host ""
Write-Host "Tip: install fzf for a better experience:"
Write-Host "     winget install fzf"
