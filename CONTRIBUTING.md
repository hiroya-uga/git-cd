# CONTRIBUTING

## Scope

This project ships the same user-facing command across two implementations:

- Bash / Zsh: `install.sh`, `bin/git-cd`
- PowerShell / Windows: `install.ps1`, `bin/git-cd.ps1`, `bin/git-cd.cmd`

Please keep behavior aligned unless a platform-specific difference is intentional and documented.

User-facing docs live at the repository root (`README.md`, `BASH.md`, `POWERSHELL.md`). Implementation-oriented notes live under [`docs/`](docs/) so contributor-only details stay out of the main user flow.

## When Making Changes

- Update both implementations when changing shared behavior.
- Update both test suites when changing a shared scenario.
- Update user-facing docs when options, install steps, defaults, or platform behavior change.
- Document intentional platform-specific differences in the implementation reference.

## Test

This project currently uses:

- `bats` for `bin/git-cd` and `install.sh`
- `Pester` for `bin/git-cd.ps1` and `install.ps1`

## Run Tests Locally

### Bash / macOS / Linux

Install `bats` if needed:

```sh
brew install bats-core
```

On Linux, install `bats` using your package manager. For example:

```sh
sudo apt install bats
```

Run the bash tests:

```sh
bats tests/bin/git-cd.bats
bats tests/install.bats
```

### PowerShell

Install `Pester` from a `pwsh` session if needed.

```powershell
Install-Module -Name Pester -Scope CurrentUser
```

Run the PowerShell tests from a `pwsh` session:

```powershell
Invoke-Pester tests/bin/git-cd.Tests.ps1
Invoke-Pester tests/install.Tests.ps1
```

Or run it without opening an interactive `pwsh` session:

```sh
pwsh -NoProfile -Command "Install-Module -Name Pester -Scope CurrentUser"
pwsh -NoProfile -Command "Invoke-Pester tests/bin/git-cd.Tests.ps1"
pwsh -NoProfile -Command "Invoke-Pester tests/install.Tests.ps1"
```

## CI

GitHub Actions runs:

- `.github/workflows/test.yml`

## Reference Docs

- Bash / PowerShell implementation reference: [docs/implementation-reference.md](docs/implementation-reference.md)

## Test Parity

`bats` and `Pester` are intended to cover the same user-facing scenarios.

The following scenarios are covered by both test suites:

| Scenario                                                 | Bash (`bats`) | PowerShell (`Pester`) |
| -------------------------------------------------------- | ------------- | --------------------- |
| Help output                                              | Yes           | Yes                   |
| Invalid search root                                      | Yes           | Yes                   |
| `--depth` without a value is an error                    | Yes           | Yes                   |
| No argument → searches default root                      | Yes           | Yes                   |
| `.` argument searches current directory                  | Yes           | Yes                   |
| `./` / `.\` argument searches current directory          | Yes           | Yes                   |
| `./cd` / `.\cd` argument searches subdirectory           | Yes           | Yes                   |
| `git-cd.root` config used as default search path         | Yes           | Yes                   |
| Repository discovery from path                           | Yes           | Yes                   |
| Depth limit excludes deeper repos                        | Yes           | Yes                   |
| `node_modules` directories are skipped                   | Yes           | Yes                   |
| Depth limit excludes all repos                           | Yes           | Yes                   |
| Depth limit includes deep repo when sufficient           | Yes           | Yes                   |
| Path + `--depth` combined                                | Yes           | Yes                   |
| `--cache` reuses the existing cache without rewriting it | Yes           | Yes                   |
| Submodules excluded by default                           | Yes           | Yes                   |
| Submodules included with `--submodules`                  | Yes           | Yes                   |
| Nested submodule recursion with `--submodules`           | Yes           | Yes                   |
| Path + `--submodules` + `--depth` combined               | Yes           | Yes                   |
| Search stays inside the specified subtree                | Yes           | Yes                   |

The following scenarios are intentionally platform-specific and covered by one test suite only:

| Scenario                                         | Covered by      | Reason                                      |
| ------------------------------------------------ | --------------- | ------------------------------------------- |
| macOS-specific ignored directories are skipped   | Bash only       | `Library` / `.Trash` are macOS-only paths   |
| Windows-specific ignored directories are skipped | PowerShell only | `AppData` / `$RECYCLE.BIN` are Windows-only |

Some assertion details are allowed to differ between the two test suites:

- Repository enumeration order may differ between bash and PowerShell implementations.
- Platform-specific ignored directories differ by implementation (`Library` / `.Trash` on bash, `AppData` / `$RECYCLE.BIN` / `System Volume Information` on PowerShell).
- When order is not stable, the PowerShell tests may assert that the result is one of the valid candidates instead of a single fixed path.
- Path formatting and stderr handling may differ slightly by shell/runtime, but the user-facing behavior should stay equivalent.

When adding or changing a scenario, update both:

- `tests/bin/git-cd.bats`
- `tests/bin/git-cd.Tests.ps1`

When adding or changing an install scenario, update both:

- `tests/install.bats`
- `tests/install.Tests.ps1`

## Pull Requests

- Summarize any user-visible behavior changes.
- Call out platform-specific decisions when Bash and PowerShell differ.
- Mention which docs were updated, or explicitly note that no doc changes were needed.
