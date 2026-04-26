# git-cd for Windows

Navigate to git repositories interactively from PowerShell.

> `git-cd.cmd` is the launcher shim for Windows, but persistent `cd` behavior is provided in PowerShell via the profile function installed by `install.ps1`. Plain `cmd.exe` can invoke the helper, but it cannot change the parent shell's current directory after the process exits.

## Usage

```powershell
git cd
```

Searches for git repositories under `$env:USERPROFILE` and displays them in an interactive list. Select one to move to that directory.

If [fzf](https://github.com/junegunn/fzf) is installed, it will be used for fuzzy selection. Otherwise, a numbered list is displayed.

### Arguments

```powershell
git cd [path]
```

Specify a starting directory to search from. Defaults to `$env:USERPROFILE`.

### Options

| Option         | Description                                              |
| -------------- | -------------------------------------------------------- |
| `--depth <n>`  | Limit directory traversal depth (default: 5)             |
| `--submodules` | Include git submodules in the list (excluded by default) |
| `--cache`      | Use cached results for faster startup                    |
| `-h, --help`   | Show this help message                                   |

## Caching

By default, repositories are searched fresh on every run and the latest result is written to the cache file. Pass `--cache` to reuse the current cached list as-is.

The cache is stored at `%LOCALAPPDATA%\git-cd\cache`.

## Installation

### Quick install

```powershell
Invoke-RestMethod https://github.com/hiroya-uga/git-cd/releases/latest/download/install.ps1 | Invoke-Expression
```

### Clone (easier to update later)

```powershell
git clone https://github.com/hiroya-uga/git-cd.git "$env:USERPROFILE\.git-cd"
& "$env:USERPROFILE\.git-cd\install.ps1"
```

To update:

```powershell
git -C "$env:USERPROFILE\.git-cd" pull
& "$env:USERPROFILE\.git-cd\install.ps1"
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

### Quick install

```powershell
Remove-Item "$env:USERPROFILE\bin\git-cd.ps1"
Remove-Item "$env:USERPROFILE\bin\git-cd.cmd"
```

Then remove the shell function from `$PROFILE` — delete the lines between `# git-cd BEGIN` and `# git-cd END`.

If `$env:USERPROFILE\bin` was added to `PATH` by the installer, you can remove it via **System Properties → Environment Variables → User variables → Path**.

### Clone install

```powershell
Remove-Item "$env:USERPROFILE\bin\git-cd.ps1"
Remove-Item "$env:USERPROFILE\bin\git-cd.cmd"
Remove-Item -Recurse "$env:USERPROFILE\.git-cd"  # adjust this path if you cloned to a different location
```

Then remove the shell function from `$PROFILE` — delete the lines between `# git-cd BEGIN` and `# git-cd END`.

## Requirements

- PowerShell 5.1 or later
- [fzf](https://github.com/junegunn/fzf) (optional, recommended — install with `winget install fzf`)
