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

If you prefer to keep shell customizations in `~/.zshrc.local`, install with:

```sh
~/.git-cd/install.sh -zl
```

Make sure your `~/.zshrc` sources `~/.zshrc.local` on startup.

`--zshrc-local` is also available as the long form.

To update:

```sh
git -C ~/.git-cd pull
```

### Quick install

> This pipes a remote script directly into the shell. Review [install.sh](install.sh) before running if you prefer to audit first.

```sh
curl -fsSL https://github.com/hiroya-uga/git-cd/releases/latest/download/install.sh | bash
```

To target `~/.zshrc.local` instead:

```sh
curl -fsSL https://github.com/hiroya-uga/git-cd/releases/latest/download/install.sh | bash -s -- -zl
```

### What `install.sh` does

1. Places `git-cd` at `~/.local/bin/git-cd`
    - Clone install: creates a symlink to the cloned script
    - Quick install: downloads the script directly
2. Adds `~/.local/bin` to `PATH` in the selected rc file
    - Default: `~/.zshrc` for zsh, `~/.bashrc` for bash
    - With `-zl` / `--zshrc-local`: `${ZDOTDIR:-$HOME}/.zshrc.local`
3. Appends a shell function to the same rc file
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

After removing the installed script (and the cloned repository, if applicable), remove the shell function from the rc file you installed into (`~/.zshrc`, `~/.zshrc.local`, or `~/.bashrc`) — delete the lines between `# git-cd BEGIN` and `# git-cd END`.

If the installer added `~/.local/bin` to `PATH`, also remove the `export PATH="$HOME/.local/bin:$PATH"` line from the same file.

## Troubleshooting

### `git cd` is not found after installation

The installer updates your selected rc file, but the change only takes effect in new shell sessions. Open a new terminal tab, or reload the rc file manually:

```sh
source ~/.zshrc  # or ~/.zshrc.local / ~/.bashrc
```

### Which rc file was updated?

By default, the installer checks the basename of `$SHELL`. If it is `zsh`, it updates `${ZDOTDIR:-$HOME}/.zshrc`; otherwise it updates `~/.bashrc`.

If you pass `-zl` or `--zshrc-local`, it updates `${ZDOTDIR:-$HOME}/.zshrc.local` instead.

### Directory change does not persist after `git cd`

The shell function was not installed, or your rc file is not sourced on startup. Check that the lines between `# git-cd BEGIN` and `# git-cd END` exist in your rc file.

### Conflict with an existing `git` shell function

If your shell already defines a `git` function, the installer will replace the block between `# git-cd BEGIN` and `# git-cd END` on re-runs. Merge any custom logic manually around those markers.

## Requirements

- bash or zsh
- [fzf](https://github.com/junegunn/fzf) (optional, recommended — for example `brew install fzf` on macOS or install it with your Linux package manager)
