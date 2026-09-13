#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_RC_BASENAME=".zshrc"

show_help() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  -zl, --zshrc-local  Install shell setup into ${ZDOTDIR:-$HOME}/.zshrc.local
  -h,  --help         Show this help message
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -zl|--zshrc-local)
      ZSH_RC_BASENAME=".zshrc.local"
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_help >&2
      exit 1
      ;;
  esac
  shift
done

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

# Determine shell type and rc file
if [ "$ZSH_RC_BASENAME" = ".zshrc.local" ]; then
  RC_FILE="${ZDOTDIR:-$HOME}/$ZSH_RC_BASENAME"
  SHELL_TYPE="zsh"
elif [ "$(basename "${SHELL:-}")" = "zsh" ]; then
  RC_FILE="${ZDOTDIR:-$HOME}/$ZSH_RC_BASENAME"
  SHELL_TYPE="zsh"
else
  RC_FILE="$HOME/.bashrc"
  SHELL_TYPE="bash"
fi

# Add INSTALL_DIR to PATH in rc file if not already present
if ! grep -q '\.local/bin' "$RC_FILE" 2>/dev/null; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$RC_FILE"
  echo "Added $INSTALL_DIR to PATH in $RC_FILE"
fi

HOOK_LINE="eval \"\$(git-cd init $SHELL_TYPE)\" # git-cd"

# Append shell hook if not already present
if grep -q "# git-cd" "$RC_FILE" 2>/dev/null; then
  echo "Shell hook already exists in $RC_FILE"
else
  printf '%s\n' "$HOOK_LINE" >> "$RC_FILE"
  echo "Added shell hook to $RC_FILE"
fi

echo ""
echo "✅ Done!"
echo "Open a new terminal tab to start using 'git cd'."
if [ "$ZSH_RC_BASENAME" = ".zshrc.local" ]; then
  echo "Make sure ${ZDOTDIR:-$HOME}/.zshrc sources $RC_FILE on startup."
fi
echo ""
echo "Tip: install fzf for a better experience:"
if [ "$(uname -s)" = "Darwin" ]; then
  echo "     macOS (Homebrew): brew install fzf"
else
  echo "     Linux: install it with your package manager"
fi
