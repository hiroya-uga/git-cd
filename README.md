# git-cd

Navigate to git repositories interactively from the command line.

## Usage

```sh
git cd
```

Searches for git repositories under `$HOME` and displays them in an interactive list. Select one to move to that directory.

If [fzf](https://github.com/junegunn/fzf) is installed, it will be used for fuzzy selection. Otherwise, a numbered list is displayed.

### Arguments

```sh
git cd [path] # git cd ./
```

Specify a starting directory to search from. Defaults to `$HOME`, or the value of `git-cd.root` if configured (see below).

### Options

| Option         | Description                                                               |
| -------------- | ------------------------------------------------------------------------- |
| `--depth <n>`  | Limit directory traversal depth (default: 5)                              |
| `--submodules` | Include git submodules in the list (excluded by default)                  |
| `--cache`      | Use cached results for faster startup                                      |
| `-h, --help`   | Show this help message                                                    |

## Configuration

You can set a default search root via git's global config — this avoids conflicts with other tools since it uses git's own config namespace:

```sh
git config --global git-cd.root ~/works
```

After this, `git cd` will search under `~/works` instead of `$HOME`. Passing an explicit path argument still overrides the configured value.

## Caching

By default, repositories are searched fresh on every run and the latest result is written to the cache file. Pass `--cache` to reuse the current cached list as-is.

The cache is stored at `~/.cache/git-cd`.

## Installation

### Quick install

```sh
curl -fsSL https://github.com/hiroya-uga/git-cd/releases/latest/download/install.sh | bash
```

### Clone (easier to update later)

```sh
git clone https://github.com/hiroya-uga/git-cd.git ~/.git-cd
~/.git-cd/install.sh
```

To update:

```sh
git -C ~/.git-cd pull
```

### What `install.sh` does

1. Places `git-cd` at `~/.local/bin/git-cd`
    - Clone install: creates a symlink to the cloned script
    - curl install: downloads the script directly
2. Adds `~/.local/bin` to `PATH` in `~/.zshrc` (or `~/.bashrc`) if not already present
3. Appends a shell function to `~/.zshrc` (or `~/.bashrc`)
    - `git cd` is handled by this function so that `cd` runs in the current shell process — without it, directory changes would not persist after the command exits

Open a new terminal tab and you're ready to go.

## Uninstall

### curl install

```sh
rm ~/.local/bin/git-cd
```

Then remove the shell function from `~/.zshrc` (or `~/.bashrc`) — delete the lines between `# git-cd` and the closing `}`.

### Clone install

```sh
rm ~/.local/bin/git-cd
rm -rf ~/.git-cd  # adjust this path if you cloned to a different location
```

Then remove the shell function from `~/.zshrc` (or `~/.bashrc`) — delete the lines between `# git-cd` and the closing `}`.

## Requirements

- bash or zsh
- [fzf](https://github.com/junegunn/fzf) (optional, recommended — install with `brew install fzf`)
