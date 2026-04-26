#!/usr/bin/env bats

# describe: test harness / shared fixture
setup() {
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/git-cd-bats.XXXXXX")"
  RESOLVED_TEST_ROOT="$(cd "$TEST_ROOT" && pwd)"
  GIT_CD_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/bin/git-cd"
  ORIGINAL_PATH="$PATH"
  FZF_CAPTURE="$TEST_ROOT/fzf-input.txt"
  CACHE_FILE="$TEST_ROOT/home/.cache/git-cd"

  mkdir -p "$TEST_ROOT/mock-bin" "$TEST_ROOT/home"
  cat > "$TEST_ROOT/mock-bin/fzf" <<'EOF'
#!/usr/bin/env bash
input=$(cat)
if [ -n "${FZF_CAPTURE:-}" ]; then
  printf '%s\n' "$input" > "$FZF_CAPTURE"
fi
printf '%s\n' "$input" | head -n 1
EOF

  chmod +x "$TEST_ROOT/mock-bin/fzf"

  mkdir -p "$TEST_ROOT/repo1/.git"
  mkdir -p "$TEST_ROOT/projects/repo2/.git"
  mkdir -p "$TEST_ROOT/a/b/repo3/.git"
  mkdir -p "$TEST_ROOT/a/b/c/d/deep-repo/.git"
  mkdir -p "$TEST_ROOT/parent/.git"
  mkdir -p "$TEST_ROOT/parent/sub"
  printf 'gitdir: ../.git/modules/sub\n' > "$TEST_ROOT/parent/sub/.git"
  mkdir -p "$TEST_ROOT/parent/components/vendor"
  printf 'gitdir: ../.git/modules/vendor\n' > "$TEST_ROOT/parent/components/vendor/.git"
  mkdir -p "$TEST_ROOT/repo1/node_modules/evil/.git"
  mkdir -p "$TEST_ROOT/Library/hidden-repo/.git"
  mkdir -p "$TEST_ROOT/.Trash/hidden-repo/.git"
}

teardown() {
  PATH="$ORIGINAL_PATH"
  rm -rf "$TEST_ROOT"
}

run_git_cd() {
  run env PATH="$TEST_ROOT/mock-bin:$ORIGINAL_PATH" HOME="$TEST_ROOT/home" FZF_CAPTURE="$FZF_CAPTURE" "$GIT_CD_SCRIPT" "$@"
}

run_git_cd_from_dir() {
  local working_dir="$1"
  shift
  run env PATH="$TEST_ROOT/mock-bin:$ORIGINAL_PATH" HOME="$TEST_ROOT/home" FZF_CAPTURE="$FZF_CAPTURE" bash -c 'cd "$1" && shift && exec "$@"' _ "$working_dir" "$GIT_CD_SCRIPT" "$@"
}

assert_capture_contains() {
  local needle="$1"
  grep -Fqx "$needle" "$FZF_CAPTURE"
}

assert_capture_not_contains() {
  local needle="$1"
  ! grep -Fqx "$needle" "$FZF_CAPTURE"
}

assert_file_contains_exactly() {
  local path="$1"
  local expected="$2"
  grep -Fqx "$expected" "$path"
}

# describe: search root argument forms
@test "searches HOME when no path argument is given" {
  local resolved_home
  mkdir -p "$TEST_ROOT/home/myrepo/.git"
  resolved_home="$(cd "$TEST_ROOT/home" && pwd)"

  run_git_cd

  [ "$status" -eq 0 ]
  [ "$output" = "$resolved_home/myrepo" ]
}

@test "searches the current directory when . is given" {
  local dir
  mkdir -p "$TEST_ROOT/dot-scope/myrepo/.git"
  dir="$(cd "$TEST_ROOT/dot-scope" && pwd)"

  run_git_cd_from_dir "$dir" .

  [ "$status" -eq 0 ]
  [ "$output" = "$dir/myrepo" ]
}

@test "searches the current directory when ./ is given" {
  local dir
  mkdir -p "$TEST_ROOT/dotslash-scope/myrepo/.git"
  dir="$(cd "$TEST_ROOT/dotslash-scope" && pwd)"

  run_git_cd_from_dir "$dir" ./

  [ "$status" -eq 0 ]
  [ "$output" = "$dir/myrepo" ]
}

@test "searches ./cd when ./cd path is given" {
  local dir
  mkdir -p "$TEST_ROOT/dotslash-cd-scope/cd/myrepo/.git"
  dir="$(cd "$TEST_ROOT/dotslash-cd-scope" && pwd)"

  run_git_cd_from_dir "$dir" ./cd

  [ "$status" -eq 0 ]
  [ "$output" = "$dir/cd/myrepo" ]
}

# describe: help and argument validation
@test "returns an error when --depth is given without a value" {
  run_git_cd "$TEST_ROOT" --depth

  [ "$status" -eq 1 ]
  [[ "$output" == *"--depth requires a value"* ]]
}

@test "returns usage text for --help" {
  run_git_cd --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: git cd [path] [options]"* ]]
}

@test "returns an error when the search root does not exist" {
  run_git_cd "$TEST_ROOT/does-not-exist"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Not a directory: $TEST_ROOT/does-not-exist"* ]]
}

@test "treats a literal cd argument as a real path" {
  local literal_root="$TEST_ROOT/literal-cd"
  local resolved_literal_root
  mkdir -p "$literal_root/cd/.git"
  resolved_literal_root="$(cd "$literal_root" && pwd)"

  run_git_cd_from_dir "$literal_root" cd

  [ "$status" -eq 0 ]
  [ "$output" = "$resolved_literal_root/cd" ]
}

@test "uses git-cd.root as default search path when configured" {
  local configured_root="$RESOLVED_TEST_ROOT/configured-root"
  local config_file="$TEST_ROOT/gitconfig"
  mkdir -p "$configured_root/myrepo/.git"
  printf '[git-cd]\n\troot = %s\n' "$configured_root" > "$config_file"

  run env PATH="$TEST_ROOT/mock-bin:$ORIGINAL_PATH" HOME="$TEST_ROOT/home" FZF_CAPTURE="$FZF_CAPTURE" GIT_CONFIG_GLOBAL="$config_file" "$GIT_CD_SCRIPT"

  [ "$status" -eq 0 ]
  [ "$output" = "$configured_root/myrepo" ]
}

# describe: repository discovery
@test "returns one of the discovered repositories from the provided path" {
  local candidates=(
    "$RESOLVED_TEST_ROOT/repo1"
    "$RESOLVED_TEST_ROOT/projects/repo2"
    "$RESOLVED_TEST_ROOT/a/b/repo3"
    "$RESOLVED_TEST_ROOT/parent"
    "$RESOLVED_TEST_ROOT/a/b/c/d/deep-repo"
  )
  local candidate

  run_git_cd "$TEST_ROOT"

  [ "$status" -eq 0 ]
  for candidate in "${candidates[@]}"; do
    if [ "$output" = "$candidate" ]; then
      return 0
    fi
  done

  echo "unexpected output: $output" >&2
  return 1
}

@test "excludes deeper repositories when --depth is smaller" {
  run_git_cd "$TEST_ROOT" --depth 3

  [ "$status" -eq 0 ]
  assert_capture_contains "$RESOLVED_TEST_ROOT/repo1"
  assert_capture_contains "$RESOLVED_TEST_ROOT/projects/repo2"
  assert_capture_contains "$RESOLVED_TEST_ROOT/a/b/repo3"
  assert_capture_not_contains "$RESOLVED_TEST_ROOT/a/b/c/d/deep-repo"
}

@test "skips node_modules directories during discovery" {
  run_git_cd "$TEST_ROOT"

  [ "$status" -eq 0 ]
  assert_capture_not_contains "$RESOLVED_TEST_ROOT/repo1/node_modules/evil"
}

@test "skips macOS-specific ignored directories during discovery" {
  run_git_cd "$TEST_ROOT"

  [ "$status" -eq 0 ]
  assert_capture_not_contains "$RESOLVED_TEST_ROOT/Library/hidden-repo"
  assert_capture_not_contains "$RESOLVED_TEST_ROOT/.Trash/hidden-repo"
}

@test "returns an error when depth excludes all repositories" {
  local deep_only="$TEST_ROOT/deep-only"
  mkdir -p "$deep_only/a/b/c/repo/.git"

  run_git_cd "$deep_only" --depth 2

  [ "$status" -eq 1 ]
  [[ "$output" == *"No git repositories found under"* ]]
}

@test "finds the deep repository when depth is sufficient" {
  local deep_only="$TEST_ROOT/deep-only"
  local resolved_deep_only
  mkdir -p "$deep_only/a/b/c/repo/.git"
  resolved_deep_only="$(cd "$deep_only" && pwd)"

  run_git_cd "$deep_only" --depth 4

  [ "$status" -eq 0 ]
  [ "$output" = "$resolved_deep_only/a/b/c/repo" ]
}

@test "limits discovery when path and --depth are combined" {
  run_git_cd "$TEST_ROOT/a" --depth 2

  [ "$status" -eq 0 ]
  assert_capture_contains "$RESOLVED_TEST_ROOT/a/b/repo3"
  assert_capture_not_contains "$RESOLVED_TEST_ROOT/a/b/c/d/deep-repo"
  [ "$output" = "$RESOLVED_TEST_ROOT/a/b/repo3" ]
}

@test "reuses the existing cache without rewriting it when --cache is enabled" {
  local cache_root="$TEST_ROOT/cache-root"
  local fresh_repo="$cache_root/live-repo"
  local stale_repo="$TEST_ROOT/stale-repo"

  mkdir -p "$fresh_repo/.git" "$(dirname "$CACHE_FILE")"
  printf '%s\n' "$stale_repo" > "$CACHE_FILE"

  run_git_cd "$cache_root" --cache

  [ "$status" -eq 0 ]
  [ "$output" = "$stale_repo" ]
  assert_file_contains_exactly "$CACHE_FILE" "$stale_repo"
  ! grep -Fqx "$fresh_repo" "$CACHE_FILE"
}

# describe: nested repository handling
@test "excludes nested gitfile repositories by default" {
  local submodule_only="$TEST_ROOT/submodule-only"
  mkdir -p "$submodule_only/sub"
  printf 'gitdir: ../.git/modules/sub\n' > "$submodule_only/sub/.git"

  run_git_cd "$submodule_only"

  [ "$status" -eq 1 ]
  [[ "$output" == *"No git repositories found under"* ]]
}

@test "includes nested gitfile repositories when --nested is enabled" {
  local submodule_only="$TEST_ROOT/submodule-only"
  local resolved_submodule_only
  mkdir -p "$submodule_only/sub"
  printf 'gitdir: ../.git/modules/sub\n' > "$submodule_only/sub/.git"
  resolved_submodule_only="$(cd "$submodule_only" && pwd)"

  run_git_cd "$submodule_only" --nested

  [ "$status" -eq 0 ]
  [ "$output" = "$resolved_submodule_only/sub" ]
}

@test "recurses into repositories to find nested gitfile repositories when --nested is enabled" {
  local isolated_root="$TEST_ROOT/submodule-recursion"
  local deep_parent="$isolated_root/deep-parent"
  local resolved_deep_parent
  mkdir -p "$deep_parent/.git"
  mkdir -p "$deep_parent/a/b/sub"
  printf 'gitdir: ../.git/modules/sub\n' > "$deep_parent/a/b/sub/.git"
  resolved_deep_parent="$(cd "$deep_parent" && pwd)"

  run_git_cd "$isolated_root" --nested

  [ "$status" -eq 0 ]
  [[ "$output" != *"node_modules"* ]]
  [[ "$output" == "$resolved_deep_parent" || "$output" == "$resolved_deep_parent/a/b/sub" ]]
}

@test "limits discovery when path, --nested, and --depth are combined" {
  local scoped_root="$TEST_ROOT/scoped-submodules"
  local resolved_scoped_root
  mkdir -p "$scoped_root/parent/.git"
  mkdir -p "$scoped_root/parent/sub"
  printf 'gitdir: ../.git/modules/sub\n' > "$scoped_root/parent/sub/.git"
  mkdir -p "$scoped_root/parent/components/vendor"
  printf 'gitdir: ../.git/modules/vendor\n' > "$scoped_root/parent/components/vendor/.git"
  resolved_scoped_root="$(cd "$scoped_root" && pwd)"

  run_git_cd "$scoped_root" --nested --depth 3

  [ "$status" -eq 0 ]
  assert_capture_contains "$resolved_scoped_root/parent"
  assert_capture_contains "$resolved_scoped_root/parent/sub"
  assert_capture_contains "$resolved_scoped_root/parent/components/vendor"
  [[ "$output" == "$resolved_scoped_root/parent" || "$output" == "$resolved_scoped_root/parent/sub" || "$output" == "$resolved_scoped_root/parent/components/vendor" ]]
}

# describe: scoped search roots
@test "limits discovery to the specified subtree" {
  local candidates=(
    "$RESOLVED_TEST_ROOT/a/b/repo3"
    "$RESOLVED_TEST_ROOT/a/b/c/d/deep-repo"
  )
  local candidate

  run_git_cd "$TEST_ROOT/a"

  [ "$status" -eq 0 ]
  for candidate in "${candidates[@]}"; do
    if [ "$output" = "$candidate" ]; then
      return 0
    fi
  done

  echo "unexpected output: $output" >&2
  return 1
}
