#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
SHELL_FUNCTION_HEAD="
# git-cd BEGIN
# Installed: $INSTALL_DATE"
SHELL_FUNCTION_BODY='
git() {
  if [ "${1:-}" = "cd" ]; then
    shift
    local dir
    dir=$(command git-cd "$@") && [ -n "$dir" ] && builtin cd "$dir"
  else
    command git "$@"
  fi
}
# git-cd END'
SHELL_FUNCTION="${SHELL_FUNCTION_HEAD}${SHELL_FUNCTION_BODY}"

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

# Add INSTALL_DIR to PATH in rc file if not already present
if ! grep -q '\.local/bin' "$RC_FILE" 2>/dev/null; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$RC_FILE"
  echo "Added $INSTALL_DIR to PATH in $RC_FILE"
fi

# Append or update shell function
if grep -q "# git-cd BEGIN" "$RC_FILE" 2>/dev/null; then
  _FUNC_FILE="$(mktemp)"
  printf '%s' "$SHELL_FUNCTION" > "$_FUNC_FILE"
  FUNC_FILE="$_FUNC_FILE" perl -i -0pe '
    my $r = do { local $/; open(my $fh, "<", $ENV{FUNC_FILE}) or die; <$fh> };
    $r =~ s/^\s*//;
    s/# git-cd BEGIN.*?# git-cd END/$r/s;
  ' "$RC_FILE"
  rm -f "$_FUNC_FILE"
  echo "Updated shell function in $RC_FILE"
else
  printf '%s\n' "$SHELL_FUNCTION" >> "$RC_FILE"
  echo "Added shell function to $RC_FILE"
fi

echo ""
echo "✅ Done!"
echo "Open a new terminal tab to start using 'git cd'."
echo ""
echo "Tip: install fzf for a better experience:"
echo "     brew install fzf"
