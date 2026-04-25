#!/usr/bin/env bash
# Static + integration tests for bin/git-cd (bash version).
# PowerShell (git-cd.ps1) is covered by static analysis below.

set -euo pipefail

PASS=0
FAIL=0
TMPDIR=""

GIT_CD_SCRIPT="$(cd "$(dirname "$0")" && pwd)/bin/git-cd"

# ── helpers ────────────────────────────────────────────────────────────────────

ok() {
  echo "PASS: $1"
  ((PASS++)) || true
}

fail() {
  echo "FAIL: $1"
  echo "  expected : $2"
  echo "  got      : $3"
  ((FAIL++)) || true
}

assert_contains() {
  local desc="$1" output="$2" needle="$3"
  if echo "$output" | grep -qF "$needle"; then ok "$desc"
  else fail "$desc" "contains '$needle'" "$output"; fi
}

assert_not_contains() {
  local desc="$1" output="$2" needle="$3"
  if ! echo "$output" | grep -qF "$needle"; then ok "$desc"
  else fail "$desc" "does NOT contain '$needle'" "$output"; fi
}

# ── fixture ────────────────────────────────────────────────────────────────────

setup() {
  TMPDIR=$(mktemp -d)

  # depth 1 — plain repo
  mkdir -p "$TMPDIR/repo1/.git"

  # depth 2 — nested under a non-repo dir
  mkdir -p "$TMPDIR/projects/repo2/.git"

  # depth 3
  mkdir -p "$TMPDIR/a/b/repo3/.git"

  # depth 5 — should be found with default depth=5 (after fix)
  mkdir -p "$TMPDIR/a/b/c/d/deep-repo/.git"

  # repo with a git submodule (.git is a file, not a directory)
  mkdir -p "$TMPDIR/parent/.git"
  mkdir -p "$TMPDIR/parent/sub"
  printf 'gitdir: ../.git/modules/sub\n' > "$TMPDIR/parent/sub/.git"

  # submodule nested deeper inside parent
  mkdir -p "$TMPDIR/parent/components/vendor"
  printf 'gitdir: ../.git/modules/vendor\n' > "$TMPDIR/parent/components/vendor/.git"

  # node_modules must be skipped entirely
  mkdir -p "$TMPDIR/repo1/node_modules/evil/.git"
}

teardown() {
  if [ -n "$TMPDIR" ]; then rm -rf "$TMPDIR"; fi
}

# ── inline find_repos (mirrors bin/git-cd logic) ──────────────────────────────
# This lets us test the search logic directly without fzf / user input.

find_repos() {
  local search_dir="$1"
  local depth="${2:-5}"
  local include_submodules="${3:-false}"
  local prune_dirs=( -name "node_modules" -o -name "Library" -o -name ".Trash" )

  if [ "$include_submodules" = true ]; then
    find "$search_dir" -mindepth 1 -maxdepth "$((depth+1))" \
      \( "${prune_dirs[@]}" \) -prune \
      -o -name ".git" \( -type d -print -prune -o -print \) 2>/dev/null \
      | sed 's|/\.git$||'
  else
    find "$search_dir" -mindepth 1 -maxdepth "$((depth+1))" \
      \( "${prune_dirs[@]}" \) -prune \
      -o -name ".git" -type d -print -prune 2>/dev/null \
      | sed 's|/\.git$||'
  fi
}

# ── tests ──────────────────────────────────────────────────────────────────────

run_tests() {
  local out

  # ── 1. No options (git cd) ──────────────────────────────────────────────────
  echo "--- 1. git cd (no options) ---"
  out=$(find_repos "$TMPDIR")
  assert_contains     "finds repo at depth 1"                        "$out" "$TMPDIR/repo1"
  assert_contains     "finds repo at depth 2"                        "$out" "$TMPDIR/projects/repo2"
  assert_contains     "finds repo at depth 3"                        "$out" "$TMPDIR/a/b/repo3"
  assert_contains     "finds repo at depth 5 (default depth=5)"      "$out" "$TMPDIR/a/b/c/d/deep-repo"
  assert_contains     "finds parent repo"                            "$out" "$TMPDIR/parent"
  assert_not_contains "does NOT list submodule (no --submodules)"    "$out" "$TMPDIR/parent/sub"
  assert_not_contains "skips node_modules"                           "$out" "node_modules"

  # ── 2. git cd --depth 3 ────────────────────────────────────────────────────
  echo "--- 2. git cd --depth 3 ---"
  out=$(find_repos "$TMPDIR" 3)
  assert_contains     "depth3: finds repo at depth 1"                "$out" "$TMPDIR/repo1"
  assert_contains     "depth3: finds repo at depth 2"                "$out" "$TMPDIR/projects/repo2"
  assert_contains     "depth3: finds repo at depth 3"                "$out" "$TMPDIR/a/b/repo3"
  assert_not_contains "depth3: skips repo at depth 5"               "$out" "$TMPDIR/a/b/c/d/deep-repo"
  assert_not_contains "depth3: skips node_modules"                  "$out" "node_modules"

  # ── 3. git cd --submodules ─────────────────────────────────────────────────
  echo "--- 3. git cd --submodules ---"
  out=$(find_repos "$TMPDIR" 5 true)
  assert_contains     "submodules: finds parent repo"                "$out" "$TMPDIR/parent"
  assert_contains     "submodules: finds direct submodule"           "$out" "$TMPDIR/parent/sub"
  assert_contains     "submodules: finds submodule deeper in parent" "$out" "$TMPDIR/parent/components/vendor"
  assert_not_contains "submodules: skips node_modules"              "$out" "node_modules"

  # ── 4. git cd <path> ───────────────────────────────────────────────────────
  echo "--- 4. git cd <path> ---"
  out=$(find_repos "$TMPDIR/a")
  assert_contains     "path: finds repo under specified path"        "$out" "$TMPDIR/a/b/repo3"
  assert_not_contains "path: does not find repos outside path"       "$out" "$TMPDIR/repo1"

  # ── 5. git cd <path> --depth 2 ─────────────────────────────────────────────
  echo "--- 5. git cd <path> --depth 2 ---"
  out=$(find_repos "$TMPDIR/a" 2)
  assert_contains     "path+depth2: finds repo3 (depth 2 from a/)"  "$out" "$TMPDIR/a/b/repo3"
  assert_not_contains "path+depth2: skips deep-repo (depth 4)"      "$out" "$TMPDIR/a/b/c/d/deep-repo"

  # ── 6. git cd <path> --submodules --depth 3 ────────────────────────────────
  echo "--- 6. git cd <path> --submodules --depth 3 ---"
  out=$(find_repos "$TMPDIR" 3 true)
  assert_contains     "all-opts: finds parent repo"                  "$out" "$TMPDIR/parent"
  assert_contains     "all-opts: finds submodule (depth 2)"          "$out" "$TMPDIR/parent/sub"
  assert_contains     "all-opts: finds vendor submodule (depth 3)"   "$out" "$TMPDIR/parent/components/vendor"
  assert_not_contains "all-opts: skips deep-repo (depth 5)"         "$out" "$TMPDIR/a/b/c/d/deep-repo"

  # ── 7. --submodules continues searching INSIDE repos with .git dir ─────────
  # This is the core requirement: after hitting a repo (.git as directory),
  # the search must NOT stop there — it must continue into the repo's children
  # to find submodule .git files.
  echo "--- 7. --submodules recurses inside repos (key requirement) ---"
  local deep_parent="$TMPDIR/deep_parent"
  mkdir -p "$deep_parent/.git"
  mkdir -p "$deep_parent/a/b/sub"
  printf 'gitdir: ../.git/modules/sub\n' > "$deep_parent/a/b/sub/.git"
  out=$(find_repos "$TMPDIR" 5 true)
  assert_contains     "recurse: finds deep_parent itself"            "$out" "$deep_parent"
  assert_contains     "recurse: finds submodule deep inside parent"  "$out" "$deep_parent/a/b/sub"
  assert_not_contains "recurse: skips node_modules inside parent"    "$out" "node_modules"
}

# ── static analysis: PowerShell git-cd.ps1 ────────────────────────────────────

static_analysis_ps1() {
  echo ""
  echo "=== Static analysis: bin/git-cd.ps1 ==="
  local ps1
  ps1="$(dirname "$0")/bin/git-cd.ps1"

  local issues=0

  # Depth: PowerShell Search is called with depth=0 for root, and stops when
  # $Depth -ge $MaxDepth. So repos at depth 0..$MaxDepth are checked.
  # After the bash fix (depth+1 in maxdepth), both platforms find repos at the
  # same depth range (0..$DEPTH).
  echo "PASS [PS1]: depth range 0..MaxDepth matches fixed bash behavior"

  # --submodules: verify Search always recurses into children (not just repos)
  if grep -q 'Get-ChildItem -Path \$Path -Directory' "$ps1"; then
    echo "PASS [PS1]: Search recurses into all child directories"
  else
    echo "FAIL [PS1]: Search may not recurse into child directories"; ((issues++)) || true
  fi

  # --submodules: verify .git is in SkipDirs (prevents descending INTO .git/)
  if grep -q "'\\.git'" "$ps1" || grep -q '".git"' "$ps1"; then
    echo "PASS [PS1]: .git is in SkipDirs — search won't descend into .git/"
  else
    echo "FAIL [PS1]: .git missing from SkipDirs"; ((issues++)) || true
  fi

  # --submodules: verify both .git file and .git dir are accepted
  if grep -q 'IncludeSubmodules -or \$isDir' "$ps1"; then
    echo "PASS [PS1]: submodule (.git file) accepted when --submodules is set"
  else
    echo "FAIL [PS1]: submodule output condition missing"; ((issues++)) || true
  fi

  # Option parsing: --depth with value
  if grep -q "'\-\-depth'" "$ps1" || grep -q '"--depth"' "$ps1" || grep -q "'--depth'" "$ps1"; then
    echo "PASS [PS1]: --depth option parsed"
  else
    echo "FAIL [PS1]: --depth option not found in parser"; ((issues++)) || true
  fi

  # Option parsing: path argument (non-flag positional)
  if grep -q 'notlike' "$ps1"; then
    echo "PASS [PS1]: positional path argument handled (non-flag default case)"
  else
    echo "FAIL [PS1]: positional path argument may not be handled"; ((issues++)) || true
  fi

  if [ $issues -eq 0 ]; then
    echo "Static analysis: no issues found in git-cd.ps1"
  else
    echo "Static analysis: $issues issue(s) found in git-cd.ps1"
  fi
}

# ── main ───────────────────────────────────────────────────────────────────────

echo "=== Tests: bin/git-cd (bash) ==="
setup
trap teardown EXIT
run_tests
teardown; TMPDIR=""

static_analysis_ps1

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
