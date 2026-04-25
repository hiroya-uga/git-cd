# CONTRIBUTING

## Test

This project uses `bats` for `bin/git-cd`.

## Run Tests Locally

Install `bats` if needed:

```sh
brew install bats-core
```

Run the tests:

```sh
bats bin/__tests__/git-cd.bats
```

## CI

GitHub Actions runs:

- `.github/workflows/test.yml`

## Test Parity

The current scenarios covered by `bats` include:

- Help output
- Invalid search root
- Repository discovery from path
- Depth limit handling
- `node_modules` / macOS ignored directories
- `--cache` behavior
- Submodule inclusion and exclusion
- Scoped searches with combined options

When adding or changing a scenario, update `bin/__tests__/git-cd.bats`.
