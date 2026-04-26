# git-cd for Bash / Zsh

Navigate to git repositories interactively from Bash or Zsh.

For common usage, options, configuration, and overall behavior, see [README.md](README.md). This page focuses on Bash / Zsh installation details and constraints.

## Installation

### Clone install

Recommended for most users.

```sh
git clone https://github.com/hiroya-uga/git-cd.git ~/.git-cd
~/.git-cd/install.sh
```

To update:

```sh
git -C ~/.git-cd pull
```

### Quick install

> This pipes a remote script directly into the shell. Review [install.sh](install.sh) before running if you prefer to audit first.

```sh
curl -fsSL https://github.com/hiroya-uga/git-cd/releases/latest/download/install.sh | bash
```

### What `install.sh` does

1. Places `git-cd` at `~/.local/bin/git-cd`
    - Clone install: creates a symlink to the cloned script
    - Quick install: downloads the script directly
2. Adds `~/.local/bin` to `PATH` in `~/.zshrc` (or `~/.bashrc`) if not already present
3. Appends a shell function to `~/.zshrc` (or `~/.bashrc`)
    - `git cd` is handled by this function so that `cd` runs in the current shell process — without it, directory changes would not persist after the command exits

Open a new terminal tab and you're ready to go.

## Uninstall

Remove the installed script:

### Clone install

```sh
rm ~/.local/bin/git-cd
rm -rf ~/.git-cd  # adjust this path if you cloned to a different location
```

### Quick install

```sh
rm ~/.local/bin/git-cd
```

After removing the installed script (and the cloned repository, if applicable), remove the shell function from `~/.zshrc` (or `~/.bashrc`) — delete the lines between `# git-cd BEGIN` and `# git-cd END`.

If the installer added `~/.local/bin` to `PATH`, also remove the `export PATH="$HOME/.local/bin:$PATH"` line from the same file.

## Troubleshooting

### `git cd` is not found after installation

The installer updates `~/.zshrc` or `~/.bashrc`, but the change only takes effect in new shell sessions. Open a new terminal tab, or reload the rc file manually:

```sh
source ~/.zshrc  # or ~/.bashrc
```

### Which rc file was updated?

The installer checks the basename of `$SHELL`. If it is `zsh`, it updates `${ZDOTDIR:-$HOME}/.zshrc`; otherwise it updates `~/.bashrc`.

### Directory change does not persist after `git cd`

The shell function was not installed, or your rc file is not sourced on startup. Check that the lines between `# git-cd BEGIN` and `# git-cd END` exist in your rc file.

### Conflict with an existing `git` shell function

If your shell already defines a `git` function, the installer will replace the block between `# git-cd BEGIN` and `# git-cd END` on re-runs. Merge any custom logic manually around those markers.

## Requirements

- bash or zsh
- [fzf](https://github.com/junegunn/fzf) (optional, recommended — for example `brew install fzf` on macOS or install it with your Linux package manager)
