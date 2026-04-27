# git-cd

Navigate to git repositories interactively from the command line.

## Installation

- macOS / Linux with Bash or Zsh: [BASH.md](BASH.md)
- Windows with PowerShell: [POWERSHELL.md](POWERSHELL.md)

## Usage

```sh
git cd
```

Searches for git repositories under your default search root and displays them in an interactive list. Select one to move to that directory.

If [fzf](https://github.com/junegunn/fzf) is installed, it will be used for fuzzy selection. Otherwise, a numbered list is displayed.

### Arguments

```sh
git cd [path] # e.g., git cd ./
```

Specify a starting directory to search from. By default, git-cd uses:

- `git config --global git-cd.root`, if set
- otherwise your home directory (`$HOME` on Bash / Zsh, `$env:USERPROFILE` on PowerShell)

### Options

| Option        | Description                                  |
| ------------- | -------------------------------------------- |
| `--depth <n>` | Limit directory traversal depth (default: 5) |
| `--nested`    | Include nested repositories                  |
| `--cache`     | Use cached results for faster startup        |
| `-h, --help`  | Show this help message                       |

## Configuration

You can set a default search root via git's global config — this avoids conflicts with other tools since it uses git's own config namespace:

```sh
git config --global git-cd.root ~/works
```

After this, `git cd` will search under `~/works` instead of your home directory. Passing an explicit path argument still overrides the configured value.

## Caching

By default, repositories are searched fresh on every run and the latest result is written to the cache file. Pass `--cache` to reuse the current cached list as-is.

| Platform   | Cache file                    |
| ---------- | ----------------------------- |
| Bash / Zsh | `~/.cache/git-cd`             |
| PowerShell | `%LOCALAPPDATA%\git-cd\cache` |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
