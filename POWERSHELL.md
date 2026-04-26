# git-cd for Windows

Navigate to git repositories interactively from PowerShell.

For common usage, options, configuration, and overall behavior, see [README.md](README.md). This page focuses on Windows-specific installation details and constraints.

## Windows-specific behavior

- Default search root, shared options, configuration, and cache behavior are documented in [README.md](README.md).
- If `fzf` is not installed, the fallback selector uses `Read-Host` in PowerShell.
- `cmd.exe` can launch the helper through `git-cd.cmd`, but only PowerShell can persist the directory change in the current shell session.

## Installation

### Clone install

Recommended for most users.

```powershell
git clone https://github.com/hiroya-uga/git-cd.git "$env:USERPROFILE\.git-cd"
& "$env:USERPROFILE\.git-cd\install.ps1"
```

To update (re-run `install.ps1` after pulling to copy the updated scripts):

```powershell
git -C "$env:USERPROFILE\.git-cd" pull
& "$env:USERPROFILE\.git-cd\install.ps1"
```

### Quick install

> This downloads and immediately executes a remote script. Review [install.ps1](install.ps1) before running if you prefer to audit first.

```powershell
Invoke-RestMethod https://github.com/hiroya-uga/git-cd/releases/latest/download/install.ps1 | Invoke-Expression
```

### What `install.ps1` does

1. Places `git-cd.ps1` and `git-cd.cmd` at `$env:USERPROFILE\bin\` and adds `$env:USERPROFILE\bin` to `PATH` if needed
    - Clone install: copies the script files (re-run `install.ps1` after `git pull` to apply updates)
    - Quick install: downloads the scripts directly from GitHub Releases
    - `git-cd.cmd` is the command shim that launches the PowerShell helper script
2. Appends a shell function to `$PROFILE` (creating the profile directory/file if needed)
    - `git cd` is handled by this function so that `cd` runs in the current shell process — without it, directory changes would not persist after the command exits

Open a new terminal and you're ready to go.

## Uninstall

Remove the installed launcher scripts:

### Clone install

```powershell
Remove-Item "$env:USERPROFILE\bin\git-cd.ps1"
Remove-Item "$env:USERPROFILE\bin\git-cd.cmd"
Remove-Item -Recurse "$env:USERPROFILE\.git-cd"  # adjust this path if you cloned to a different location
```

### Quick install

```powershell
Remove-Item "$env:USERPROFILE\bin\git-cd.ps1"
Remove-Item "$env:USERPROFILE\bin\git-cd.cmd"
```

After removing the installed scripts (and the cloned repository, if applicable), remove the shell function from `$PROFILE` — delete the lines between `# git-cd BEGIN` and `# git-cd END`.

If `$env:USERPROFILE\bin` was added to `PATH` by the installer, you can remove it via **System Properties → Environment Variables → User variables → Path**.

## Troubleshooting

### `git cd` is not found after installation

The installer updates `$PROFILE`, but the change only takes effect in new shell sessions. Open a new terminal, or reload the profile manually:

```powershell
. $PROFILE
```

### `$PROFILE` is not loaded or execution policy blocks scripts

If PowerShell refuses to run profile scripts, allow locally created scripts:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Directory change does not persist after `git cd`

The PowerShell profile function was not installed, or `$PROFILE` is not loaded on startup. Check that the lines between `# git-cd BEGIN` and `# git-cd END` exist in `$PROFILE`.

### Conflict with an existing `git` PowerShell function

If `$PROFILE` already defines a `function git`, the installer will replace the block between `# git-cd BEGIN` and `# git-cd END` on re-runs. Merge any custom logic manually around those markers.

### `cmd.exe` cannot change directory

`git-cd.cmd` can only print the selected path. Persistent directory changes require PowerShell — `cmd.exe` cannot change the parent shell's working directory after the process exits.

## Requirements

- PowerShell 5.1 or later
- [fzf](https://github.com/junegunn/fzf) (optional, recommended — install with `winget install fzf`)
