#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

setup() {
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/install-bats.XXXXXX")"
  FAKE_HOME="$TEST_ROOT/home"
  MOCK_BIN="$TEST_ROOT/mock-bin"
  mkdir -p "$FAKE_HOME" "$MOCK_BIN"

  cat > "$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    shift
    printf '#!/usr/bin/env bash\necho mock-git-cd\n' > "$1"
    exit 0
  fi
  shift
done
EOF
  chmod +x "$MOCK_BIN/curl"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

run_install() {
  local shell="${1:-/bin/bash}"
  shift || true
  run env HOME="$FAKE_HOME" SHELL="$shell" PATH="$MOCK_BIN:$PATH" bash "$INSTALL_SH" "$@"
}

# Run a copy of install.sh placed in an isolated dir (no bin/git-cd) to trigger the curl path
run_quick_install() {
  local shell="${1:-/bin/bash}"
  shift || true
  local dir="$TEST_ROOT/quick"
  mkdir -p "$dir"
  cp "$INSTALL_SH" "$dir/install.sh"
  run env HOME="$FAKE_HOME" SHELL="$shell" PATH="$MOCK_BIN:$PATH" bash "$dir/install.sh" "$@"
}

# describe: clone install

@test "clone install: creates a symlink at ~/.local/bin/git-cd" {
  run_install

  [ "$status" -eq 0 ]
  [ -L "$FAKE_HOME/.local/bin/git-cd" ]
}

@test "clone install: symlink points to bin/git-cd in the repo" {
  run_install

  [ "$(readlink "$FAKE_HOME/.local/bin/git-cd")" = "$REPO_ROOT/bin/git-cd" ]
}

@test "clone install: is idempotent" {
  run_install
  run_install

  [ "$status" -eq 0 ]
  [ -L "$FAKE_HOME/.local/bin/git-cd" ]
  [ "$(readlink "$FAKE_HOME/.local/bin/git-cd")" = "$REPO_ROOT/bin/git-cd" ]
}

# describe: quick install (curl)

@test "quick install: creates git-cd at ~/.local/bin/git-cd" {
  run_quick_install

  [ "$status" -eq 0 ]
  [ -f "$FAKE_HOME/.local/bin/git-cd" ]
}

@test "quick install: makes downloaded git-cd executable" {
  run_quick_install

  [ -x "$FAKE_HOME/.local/bin/git-cd" ]
}

# describe: PATH setup

@test "adds PATH export to rc file when .local/bin is not present" {
  run_install

  [ "$status" -eq 0 ]
  grep -q '.local/bin' "$FAKE_HOME/.bashrc"
}

@test "does not add PATH export when .local/bin already present" {
  printf 'export PATH="$HOME/.local/bin:$PATH"\n' > "$FAKE_HOME/.bashrc"

  run_install

  [ "$status" -eq 0 ]
  [ "$(grep -c '.local/bin' "$FAKE_HOME/.bashrc")" -eq 1 ]
}

# describe: shell function setup

@test "adds shell function with BEGIN/END markers to rc file" {
  run_install

  [ "$status" -eq 0 ]
  grep -q '# git-cd BEGIN' "$FAKE_HOME/.bashrc"
  grep -q '# git-cd END' "$FAKE_HOME/.bashrc"
}

@test "adds Installed date comment to rc file" {
  run_install

  [ "$status" -eq 0 ]
  grep -q '# Installed:' "$FAKE_HOME/.bashrc"
}

@test "updates shell function when already present" {
  printf '# git-cd BEGIN\n# Installed: 2000-01-01 00:00:00\ngit() { : ; }\n# git-cd END\n' > "$FAKE_HOME/.bashrc"

  run_install

  [ "$status" -eq 0 ]
  [ "$(grep -c '# git-cd BEGIN' "$FAKE_HOME/.bashrc")" -eq 1 ]
  ! grep -q '# Installed: 2000-01-01 00:00:00' "$FAKE_HOME/.bashrc"
}

@test "added shell function forwards args to git-cd" {
  run_install

  grep -q 'command git-cd' "$FAKE_HOME/.bashrc"
}

# describe: shell detection

@test "writes to .bashrc when SHELL is bash" {
  run_install /bin/bash

  [ "$status" -eq 0 ]
  [ -f "$FAKE_HOME/.bashrc" ]
  grep -q 'git-cd' "$FAKE_HOME/.bashrc"
}

@test "writes to .zshrc when SHELL is zsh" {
  unset ZDOTDIR
  run env HOME="$FAKE_HOME" SHELL="/bin/zsh" PATH="$MOCK_BIN:$PATH" bash "$INSTALL_SH"

  [ "$status" -eq 0 ]
  [ -f "$FAKE_HOME/.zshrc" ]
  grep -q 'git-cd' "$FAKE_HOME/.zshrc"
}

@test "writes to ZDOTDIR/.zshrc when ZDOTDIR is set" {
  local zdotdir="$FAKE_HOME/zdotdir"
  mkdir -p "$zdotdir"

  run env HOME="$FAKE_HOME" SHELL="/bin/zsh" ZDOTDIR="$zdotdir" PATH="$MOCK_BIN:$PATH" bash "$INSTALL_SH"

  [ "$status" -eq 0 ]
  [ -f "$zdotdir/.zshrc" ]
  grep -q 'git-cd' "$zdotdir/.zshrc"
}

@test "writes to .zshrc.local when --zshrc-local is passed" {
  run_install /bin/zsh --zshrc-local

  [ "$status" -eq 0 ]
  [ -f "$FAKE_HOME/.zshrc.local" ]
  grep -q 'git-cd' "$FAKE_HOME/.zshrc.local"
  [ ! -e "$FAKE_HOME/.zshrc" ]
}

@test "writes to .zshrc.local when -zl is passed" {
  run_install /bin/zsh -zl

  [ "$status" -eq 0 ]
  [ -f "$FAKE_HOME/.zshrc.local" ]
  grep -q 'git-cd' "$FAKE_HOME/.zshrc.local"
  [ ! -e "$FAKE_HOME/.zshrc" ]
}

@test "writes to ZDOTDIR/.zshrc.local when ZDOTDIR is set and --zshrc-local is passed" {
  local zdotdir="$FAKE_HOME/zdotdir"
  mkdir -p "$zdotdir"

  run env HOME="$FAKE_HOME" SHELL="/bin/zsh" ZDOTDIR="$zdotdir" PATH="$MOCK_BIN:$PATH" bash "$INSTALL_SH" --zshrc-local

  [ "$status" -eq 0 ]
  [ -f "$zdotdir/.zshrc.local" ]
  grep -q 'git-cd' "$zdotdir/.zshrc.local"
  [ ! -e "$zdotdir/.zshrc" ]
}

@test "completion message suggests a platform-appropriate fzf install hint" {
  run_install

  [ "$status" -eq 0 ]

  if [ "$(uname -s)" = "Darwin" ]; then
    [[ "$output" == *"macOS (Homebrew): brew install fzf"* ]]
  else
    [[ "$output" == *"Linux: install it with your package manager"* ]]
  fi
}
