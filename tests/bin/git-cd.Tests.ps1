$ErrorActionPreference = 'Stop'

Describe 'git-cd.ps1' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:ScriptUnderTest = Join-Path $script:RepoRoot 'bin/git-cd.ps1'

        function New-TestFixture {
            $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("git-cd-pester-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
            if (-not $IsWindows) { $testRoot = (& realpath $testRoot) }

            $mockBin = Join-Path $testRoot 'mock-bin'
            New-Item -ItemType Directory -Force -Path $mockBin | Out-Null

            @'
#!/usr/bin/env bash
input=$(cat)
if [ -n "${FZF_CAPTURE:-}" ]; then
  printf '%s\n' "$input" > "$FZF_CAPTURE"
fi
printf '%s\n' "$input" | head -n 1
'@ | Set-Content -Path (Join-Path $mockBin 'fzf') -NoNewline
            if (-not $IsWindows) {
                & chmod +x (Join-Path $mockBin 'fzf')
            }

            @'
$lines = @($input)
if ($env:FZF_CAPTURE) {
    $lines | Set-Content -Path $env:FZF_CAPTURE
}
$lines | Select-Object -First 1
'@ | Set-Content -Path (Join-Path $mockBin 'fzf.ps1') -NoNewline
            @'
@echo off
pwsh -NoProfile -File "%~dp0fzf.ps1"
'@ | Set-Content -Path (Join-Path $mockBin 'fzf.cmd') -NoNewline

            New-Item -ItemType Directory -Force -Path (Join-Path $testRoot 'windows-home') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $testRoot 'windows-localappdata') | Out-Null

            return $testRoot
        }

        function Remove-TestFixture {
            param([string]$TestRoot)

            if ($TestRoot -and (Test-Path $TestRoot)) {
                Remove-Item -Recurse -Force $TestRoot
            }
        }

        function New-RepoFixture {
            param([string]$TestRoot)

            $root = Join-Path $TestRoot 'repos'

            New-Item -ItemType Directory -Force -Path (Join-Path $root 'repo1/.git') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $root 'projects/repo2/.git') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $root 'a/b/repo3/.git') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $root 'a/b/c/d/deep-repo/.git') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $root 'parent/.git') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $root 'parent/sub') | Out-Null
            'gitdir: ../.git/modules/sub' | Set-Content -Path (Join-Path $root 'parent/sub/.git') -NoNewline
            New-Item -ItemType Directory -Force -Path (Join-Path $root 'parent/components/vendor') | Out-Null
            'gitdir: ../.git/modules/vendor' | Set-Content -Path (Join-Path $root 'parent/components/vendor/.git') -NoNewline
            New-Item -ItemType Directory -Force -Path (Join-Path $root 'repo1/node_modules/evil/.git') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $root 'AppData/hidden-repo/.git') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $root '$RECYCLE.BIN/hidden-repo/.git') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $root 'System Volume Information/hidden-repo/.git') | Out-Null

            return $root
        }

        function Invoke-GitCdPs1 {
            param(
                [string]$TestRoot,
                [string[]]$Arguments,
                [string]$WorkingDirectory = $script:RepoRoot,
                [hashtable]$ExtraEnv = @{}
            )

            $stdoutFile = Join-Path $TestRoot 'stdout.txt'
            $stderrFile = Join-Path $TestRoot 'stderr.txt'
            $originalPath = $env:PATH
            $originalUserProfile = $env:USERPROFILE
            $originalLocalAppData = $env:LOCALAPPDATA
            $originalFzfCapture = $env:FZF_CAPTURE
            $fzfCapture = Join-Path $TestRoot 'fzf-input.txt'
            $env:USERPROFILE = Join-Path $TestRoot 'windows-home'
            $env:LOCALAPPDATA = Join-Path $TestRoot 'windows-localappdata'
            $env:FZF_CAPTURE = $fzfCapture
            $env:PATH = "{0}{1}{2}" -f (Join-Path $TestRoot 'mock-bin'), [System.IO.Path]::PathSeparator, $env:PATH

            $savedExtraEnv = @{}
            foreach ($key in $ExtraEnv.Keys) {
                $savedExtraEnv[$key] = [Environment]::GetEnvironmentVariable($key)
                [Environment]::SetEnvironmentVariable($key, $ExtraEnv[$key])
            }

            try {
                $pwshCommand = (Get-Command pwsh).Source
                $argumentList = @('-NoProfile', '-File', $script:ScriptUnderTest) + $Arguments
                $process = Start-Process -FilePath $pwshCommand `
                    -ArgumentList $argumentList `
                    -WorkingDirectory $WorkingDirectory `
                    -RedirectStandardOutput $stdoutFile `
                    -RedirectStandardError $stderrFile `
                    -NoNewWindow `
                    -PassThru `
                    -Wait
            } finally {
                $env:PATH = $originalPath
                if ($null -eq $originalUserProfile) { Remove-Item Env:USERPROFILE -ErrorAction SilentlyContinue } else { $env:USERPROFILE = $originalUserProfile }
                if ($null -eq $originalLocalAppData) { Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue } else { $env:LOCALAPPDATA = $originalLocalAppData }
                if ($null -eq $originalFzfCapture) { Remove-Item Env:FZF_CAPTURE -ErrorAction SilentlyContinue } else { $env:FZF_CAPTURE = $originalFzfCapture }
                foreach ($key in $savedExtraEnv.Keys) {
                    [Environment]::SetEnvironmentVariable($key, $savedExtraEnv[$key])
                }
            }

            $stderrRaw = if (Test-Path $stderrFile) { Get-Content -Raw $stderrFile } else { '' }
            $stdoutRaw = if (Test-Path $stdoutFile) { Get-Content -Raw $stdoutFile } else { '' }
            $candidateList = if (Test-Path $fzfCapture) { @(Get-Content $fzfCapture) } else { @() }

            [pscustomobject]@{
                Status = $process.ExitCode
                Stdout = if ($stdoutRaw) { $stdoutRaw.TrimEnd() } else { '' }
                Stderr = if ($stderrRaw) { $stderrRaw.TrimEnd() } else { '' }
                CandidateList = $candidateList
            }
        }

    }

    BeforeEach {
        $TestRoot = New-TestFixture
    }

    AfterEach {
        Remove-TestFixture $TestRoot
    }

    Context 'help and validation' {
        It 'returns usage text for --help' {
            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @('--help')

            $result.Status | Should -Be 0
            $result.Stdout | Should -Match 'Usage: git cd \[path\] \[options\]'
        }

        It 'returns an error when the search root does not exist' {
            $missingPath = Join-Path $TestRoot 'does-not-exist'
            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($missingPath)

            $result.Status | Should -Be 1
            $result.Stderr | Should -Match ([regex]::Escape("Not a directory: $missingPath"))
        }

        It 'returns an error when --depth is given without a value' {
            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @('--depth')

            $result.Status | Should -Be 1
            $result.Stderr | Should -Match '--depth requires a value'
        }

        It 'treats a literal cd argument as a real path' {
            $literalRoot = Join-Path $TestRoot 'literal-cd'
            New-Item -ItemType Directory -Force -Path (Join-Path $literalRoot 'cd/.git') | Out-Null

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -WorkingDirectory $literalRoot -Arguments @('cd')

            $result.Status | Should -Be 0
            $result.Stdout | Should -Match ([regex]::Escape([IO.Path]::DirectorySeparatorChar + 'literal-cd' + [IO.Path]::DirectorySeparatorChar + 'cd') + '$')
        }
    }

    Context 'repository discovery' {
        It 'returns one of the discovered repositories from the provided path' {
            $root = New-RepoFixture -TestRoot $TestRoot
            $expected = @(
                (Join-Path $root 'repo1'),
                (Join-Path $root 'projects/repo2'),
                (Join-Path $root 'a/b/repo3'),
                (Join-Path $root 'parent'),
                (Join-Path $root 'a/b/c/d/deep-repo')
            )

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($root)

            $result.Status | Should -Be 0
            $result.Stdout | Should -BeIn $expected
        }

        It 'excludes deeper repositories when --depth is smaller' {
            $root = New-RepoFixture -TestRoot $TestRoot
            $shallowRepos = @(
                (Join-Path $root 'repo1'),
                (Join-Path $root 'projects/repo2'),
                (Join-Path $root 'a/b/repo3'),
                (Join-Path $root 'parent')
            )

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($root, '--depth', '3')

            $result.Status | Should -Be 0
            $result.Stdout | Should -BeIn $shallowRepos
            $result.CandidateList | Should -Contain (Join-Path $root 'repo1')
            $result.CandidateList | Should -Contain (Join-Path $root 'projects/repo2')
            $result.CandidateList | Should -Contain (Join-Path $root 'a/b/repo3')
            $result.CandidateList | Should -Not -Contain (Join-Path $root 'a/b/c/d/deep-repo')
        }

        It 'skips node_modules directories during discovery' {
            $root = New-RepoFixture -TestRoot $TestRoot

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($root)

            $result.Status | Should -Be 0
            $result.CandidateList | Should -Not -Contain (Join-Path $root 'repo1/node_modules/evil')
        }

        It 'skips Windows-specific ignored directories during discovery' {
            $root = New-RepoFixture -TestRoot $TestRoot

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($root)

            $result.Status | Should -Be 0
            $result.CandidateList | Should -Not -Contain (Join-Path $root 'AppData/hidden-repo')
            $result.CandidateList | Should -Not -Contain (Join-Path $root '$RECYCLE.BIN/hidden-repo')
            $result.CandidateList | Should -Not -Contain (Join-Path $root 'System Volume Information/hidden-repo')
        }

        It 'returns an error when depth excludes all repositories' {
            $deepOnly = Join-Path $TestRoot 'deep-only'
            New-Item -ItemType Directory -Force -Path (Join-Path $deepOnly 'a/b/c/repo/.git') | Out-Null

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($deepOnly, '--depth', '2')

            $result.Status | Should -Be 1
            $result.Stderr | Should -Match 'No git repositories found under'
        }

        It 'finds the deep repository when depth is sufficient' {
            $deepOnly = Join-Path $TestRoot 'deep-only'
            New-Item -ItemType Directory -Force -Path (Join-Path $deepOnly 'a/b/c/repo/.git') | Out-Null

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($deepOnly, '--depth', '4')

            $result.Status | Should -Be 0
            $result.Stdout | Should -Be (Join-Path $deepOnly 'a/b/c/repo')
        }

        It 'limits discovery when path and --depth are combined' {
            $root = New-RepoFixture -TestRoot $TestRoot

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @((Join-Path $root 'a'), '--depth', '2')

            $result.Status | Should -Be 0
            $result.CandidateList | Should -Contain (Join-Path $root 'a/b/repo3')
            $result.CandidateList | Should -Not -Contain (Join-Path $root 'a/b/c/d/deep-repo')
            $result.Stdout | Should -Be (Join-Path $root 'a/b/repo3')
        }

        It 'reuses the existing cache without rewriting it when --cache is enabled' {
            $cacheRoot = Join-Path $TestRoot 'cache-root'
            $freshRepo = Join-Path $cacheRoot 'live-repo'
            $staleRepo = Join-Path $TestRoot 'stale-repo'
            $cacheFile = Join-Path (Join-Path $TestRoot 'windows-localappdata') 'git-cd\cache'
            $cacheDir = Split-Path $cacheFile -Parent

            New-Item -ItemType Directory -Force -Path (Join-Path $freshRepo '.git') | Out-Null
            New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
            $staleRepo | Set-Content -Path $cacheFile

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($cacheRoot, '--cache')
            $cacheContents = @(Get-Content $cacheFile)

            $result.Status | Should -Be 0
            $result.Stdout | Should -Be $staleRepo
            $cacheContents | Should -Contain $staleRepo
            $cacheContents | Should -Not -Contain $freshRepo
        }
    }

    Context 'submodule handling' {
        It 'excludes submodules by default' {
            $submoduleOnly = Join-Path $TestRoot 'submodule-only'
            New-Item -ItemType Directory -Force -Path (Join-Path $submoduleOnly 'sub') | Out-Null
            'gitdir: ../.git/modules/sub' | Set-Content -Path (Join-Path $submoduleOnly 'sub/.git') -NoNewline

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($submoduleOnly)

            $result.Status | Should -Be 1
            $result.Stderr | Should -Match 'No git repositories found under'
        }

        It 'includes submodules when --submodules is enabled' {
            $submoduleOnly = Join-Path $TestRoot 'submodule-only'
            New-Item -ItemType Directory -Force -Path (Join-Path $submoduleOnly 'sub') | Out-Null
            'gitdir: ../.git/modules/sub' | Set-Content -Path (Join-Path $submoduleOnly 'sub/.git') -NoNewline

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($submoduleOnly, '--submodules')

            $result.Status | Should -Be 0
            $result.Stdout | Should -Be (Join-Path $submoduleOnly 'sub')
        }

        It 'recurses into repositories to find nested submodules when --submodules is enabled' {
            $deepParent = Join-Path $TestRoot 'deep-parent'
            New-Item -ItemType Directory -Force -Path (Join-Path $deepParent '.git') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $deepParent 'a/b/sub') | Out-Null
            'gitdir: ../.git/modules/sub' | Set-Content -Path (Join-Path $deepParent 'a/b/sub/.git') -NoNewline
            $expected = @(
                $deepParent,
                (Join-Path $deepParent 'a/b/sub')
            )

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($TestRoot, '--submodules')

            $result.Status | Should -Be 0
            $result.Stdout | Should -BeIn $expected
            $result.Stdout | Should -Not -Match 'node_modules'
        }

        It 'limits discovery when path, --submodules, and --depth are combined' {
            $scopedRoot = Join-Path $TestRoot 'scoped-submodules'
            New-Item -ItemType Directory -Force -Path (Join-Path $scopedRoot 'parent/.git') | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $scopedRoot 'parent/sub') | Out-Null
            'gitdir: ../.git/modules/sub' | Set-Content -Path (Join-Path $scopedRoot 'parent/sub/.git') -NoNewline
            New-Item -ItemType Directory -Force -Path (Join-Path $scopedRoot 'parent/components/vendor') | Out-Null
            'gitdir: ../.git/modules/vendor' | Set-Content -Path (Join-Path $scopedRoot 'parent/components/vendor/.git') -NoNewline
            $expected = @(
                (Join-Path $scopedRoot 'parent'),
                (Join-Path $scopedRoot 'parent/sub'),
                (Join-Path $scopedRoot 'parent/components/vendor')
            )

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @($scopedRoot, '--submodules', '--depth', '3')

            $result.Status | Should -Be 0
            $result.CandidateList | Should -Contain (Join-Path $scopedRoot 'parent')
            $result.CandidateList | Should -Contain (Join-Path $scopedRoot 'parent/sub')
            $result.CandidateList | Should -Contain (Join-Path $scopedRoot 'parent/components/vendor')
            $result.Stdout | Should -BeIn $expected
        }
    }

    Context 'default search root' {
        It 'searches USERPROFILE when no path argument is given' {
            $homeDir = Join-Path $TestRoot 'windows-home'
            New-Item -ItemType Directory -Force -Path (Join-Path $homeDir 'myrepo/.git') | Out-Null

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @()

            $result.Status | Should -Be 0
            $result.Stdout | Should -Be (Join-Path $homeDir 'myrepo')
        }

        It 'uses git-cd.root as default search path when configured' {
            $configuredRoot = Join-Path $TestRoot 'configured-root'
            New-Item -ItemType Directory -Force -Path (Join-Path $configuredRoot 'myrepo/.git') | Out-Null
            $configFile = Join-Path $TestRoot 'gitconfig'
            $configuredRootForGit = $configuredRoot -replace '\\', '/'
            "[git-cd]`n`troot = $configuredRootForGit" | Set-Content $configFile

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @() -ExtraEnv @{ GIT_CONFIG_GLOBAL = $configFile }

            $result.Status | Should -Be 0
            $result.Stdout | Should -Be (Join-Path $configuredRoot 'myrepo')
        }
    }

    Context 'search root argument forms' {
        It 'searches the current directory when . is given' {
            $dir = Join-Path $TestRoot 'dot-scope'
            New-Item -ItemType Directory -Force -Path (Join-Path $dir 'myrepo/.git') | Out-Null

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @('.') -WorkingDirectory $dir

            $result.Status | Should -Be 0
            $result.Stdout | Should -Be (Join-Path $dir 'myrepo')
        }

        It 'searches the current directory when .\ is given' {
            $dir = Join-Path $TestRoot 'dotslash-scope'
            New-Item -ItemType Directory -Force -Path (Join-Path $dir 'myrepo/.git') | Out-Null

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @('.\') -WorkingDirectory $dir

            $result.Status | Should -Be 0
            $result.Stdout | Should -Be (Join-Path $dir 'myrepo')
        }

        It 'ignores forwarded git subcommand cd when no explicit path is given' {
            $homeDir = Join-Path $TestRoot 'windows-home'
            New-Item -ItemType Directory -Force -Path (Join-Path $homeDir 'myrepo/.git') | Out-Null

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @('cd')

            $result.Status | Should -Be 0
            $result.Stdout | Should -Be (Join-Path $homeDir 'myrepo')
        }

        It 'searches .\cd when .\cd path is given' {
            $dir = Join-Path $TestRoot 'dotslash-cd-scope'
            New-Item -ItemType Directory -Force -Path (Join-Path $dir 'cd/myrepo/.git') | Out-Null

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @('.\cd') -WorkingDirectory $dir

            $result.Status | Should -Be 0
            $result.Stdout | Should -Be (Join-Path $dir 'cd/myrepo')
        }
    }

    Context 'scoped search roots' {
        It 'limits discovery to the specified subtree' {
            $root = New-RepoFixture -TestRoot $TestRoot
            $expected = @(
                (Join-Path $root 'a/b/repo3'),
                (Join-Path $root 'a/b/c/d/deep-repo')
            )

            $result = Invoke-GitCdPs1 -TestRoot $TestRoot -Arguments @((Join-Path $root 'a'))

            $result.Status | Should -Be 0
            $result.Stdout | Should -BeIn $expected
        }
    }
}
