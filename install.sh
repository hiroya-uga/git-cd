#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SHELL_FUNCTION='
# git-cd: navigate to git repositories interactively
git() {
  if [ "${1:-}" = "cd" ]; then
    shift
    local dir
    dir=$(command git-cd "$@") && [ -n "$dir" ] && builtin cd "$dir"
  else
    command git "$@"
  fi
}'

if [ -f "$SCRIPT_DIR/bin/git-cd" ]; then
  # Clone install: create a symlink so `git pull` automatically reflects updates
  mkdir -p "$INSTALL_DIR"
  ln -sf "$SCRIPT_DIR/bin/git-cd" "$INSTALL_DIR/git-cd"
  echo "Created symlink: $INSTALL_DIR/git-cd -> $SCRIPT_DIR/bin/git-cd"
else
  # curl install: fetch the binary from GitHub Releases
  mkdir -p "$INSTALL_DIR"
  curl -fsSL https://github.com/hiroya-uga/git-cd/releases/latest/download/git-cd \
    -o "$INSTALL_DIR/git-cd"
  chmod +x "$INSTALL_DIR/git-cd"
  echo "Downloaded: $INSTALL_DIR/git-cd"
fi

# Determine rc file
if [ "$(basename "${SHELL:-}")" = "zsh" ]; then
  RC_FILE="${ZDOTDIR:-$HOME}/.zshrc"
else
  RC_FILE="$HOME/.bashrc"
fi

# Append shell function if not already present
if grep -q "# git-cd" "$RC_FILE" 2>/dev/null; then
  echo "Shell function already exists in $RC_FILE"
else
  printf '%s\n' "$SHELL_FUNCTION" >> "$RC_FILE"
  echo "Added shell function to $RC_FILE"
fi

echo ""
echo "✅ Done!"
echo "Open a new terminal tab to start using 'git cd'."
