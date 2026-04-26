$ErrorActionPreference = 'Stop'

Describe 'install.ps1' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:InstallScript = Join-Path $script:RepoRoot 'install.ps1'

        function New-TestFixture {
            $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("install-pester-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Force -Path (Join-Path $testRoot 'home') | Out-Null
            return $testRoot
        }

        function Remove-TestFixture {
            param([string]$TestRoot)
            if ($TestRoot -and (Test-Path $TestRoot)) {
                Remove-Item -Recurse -Force $TestRoot
            }
        }

        function Invoke-InstallPs1 {
            param(
                [string]$TestRoot,
                [bool]$HasLocalBin = $true,
                [bool]$MockWebRequest = $false,
                [string]$ExistingProfileContent = $null
            )

            $testHome    = Join-Path $TestRoot 'home'
            $profilePath = Join-Path $TestRoot 'ps-profile.ps1'
            $stdoutFile  = Join-Path $TestRoot 'stdout.txt'
            $stderrFile  = Join-Path $TestRoot 'stderr.txt'

            if ($null -ne $ExistingProfileContent) {
                $ExistingProfileContent | Set-Content $profilePath -NoNewline
            }

            # Determine which install.ps1 to call.
            # Clone path: call the repo's install.ps1 directly — the repo root has bin\,
            # so git-cd.ps1 and git-cd.cmd will be found by install.ps1.
            # Quick path: copy install.ps1 to a temp dir without bin\ so the download branch runs.
            if ($HasLocalBin) {
                $installTarget = $script:InstallScript
            } else {
                $quickDir = Join-Path $TestRoot 'quick'
                New-Item -ItemType Directory -Force -Path $quickDir | Out-Null
                $installTarget = Join-Path $quickDir 'install.ps1'
                Copy-Item $script:InstallScript $installTarget
            }

            # Build a wrapper script that overrides $PROFILE (global so child scopes see it)
            # and calls install.ps1 with & so $PSScriptRoot is set to install.ps1's own directory.
            $profileEsc = $profilePath  -replace "'", "''"
            $homeEsc    = $testHome     -replace "'", "''"
            $targetEsc  = $installTarget -replace "'", "''"

            $wrapperLines = [System.Collections.Generic.List[string]]::new()
            if ($MockWebRequest) {
                $wrapperLines.Add(@'
function global:Invoke-WebRequest {
    param([string]$Uri, [string]$OutFile)
    '# mock downloaded' | Set-Content $OutFile
}
'@)
            }
            $wrapperLines.Add("`$global:PROFILE = '$profileEsc'")
            $wrapperLines.Add("`$env:USERPROFILE = '$homeEsc'")
            $wrapperLines.Add("& '$targetEsc'")

            $wrapperPath = Join-Path $TestRoot 'wrapper.ps1'
            ($wrapperLines -join "`n") | Set-Content $wrapperPath -NoNewline

            $pwshCommand = (Get-Command pwsh).Source
            $process = Start-Process -FilePath $pwshCommand `
                -ArgumentList @('-NoProfile', '-File', $wrapperPath) `
                -RedirectStandardOutput $stdoutFile `
                -RedirectStandardError  $stderrFile `
                -NoNewWindow `
                -PassThru `
                -Wait

            $stdout = ((Get-Content $stdoutFile) -join "`n").TrimEnd()
            $stderr = ((Get-Content $stderrFile) -join "`n").TrimEnd()

            [pscustomobject]@{
                Status     = $process.ExitCode
                Stdout     = $stdout
                Stderr     = $stderr
                InstallDir = Join-Path $testHome 'bin'
                Profile    = $profilePath
            }
        }
    }

    BeforeEach {
        $TestRoot = New-TestFixture
    }

    AfterEach {
        Remove-TestFixture $TestRoot
    }

    Context 'clone install' {
        It 'copies git-cd.ps1 to the install directory' {
            $result = Invoke-InstallPs1 -TestRoot $TestRoot

            $result.Status | Should -Be 0
            Test-Path (Join-Path $result.InstallDir 'git-cd.ps1') | Should -Be $true
        }

        It 'copies git-cd.cmd to the install directory' {
            $result = Invoke-InstallPs1 -TestRoot $TestRoot

            $result.Status | Should -Be 0
            Test-Path (Join-Path $result.InstallDir 'git-cd.cmd') | Should -Be $true
        }

        It 'is idempotent' {
            Invoke-InstallPs1 -TestRoot $TestRoot | Out-Null
            $result = Invoke-InstallPs1 -TestRoot $TestRoot

            $result.Status | Should -Be 0
            Test-Path (Join-Path $result.InstallDir 'git-cd.ps1') | Should -Be $true
        }
    }

    Context 'quick install' {
        It 'downloads git-cd.ps1 when local bin is not available' {
            $result = Invoke-InstallPs1 -TestRoot $TestRoot -HasLocalBin $false -MockWebRequest $true

            $result.Status | Should -Be 0
            Test-Path (Join-Path $result.InstallDir 'git-cd.ps1') | Should -Be $true
        }

        It 'downloads git-cd.cmd when local bin is not available' {
            $result = Invoke-InstallPs1 -TestRoot $TestRoot -HasLocalBin $false -MockWebRequest $true

            $result.Status | Should -Be 0
            Test-Path (Join-Path $result.InstallDir 'git-cd.cmd') | Should -Be $true
        }
    }

    Context 'install directory' {
        It 'creates the install directory when it does not exist' {
            $result = Invoke-InstallPs1 -TestRoot $TestRoot

            $result.Status | Should -Be 0
            Test-Path $result.InstallDir -PathType Container | Should -Be $true
        }
    }

    Context 'profile setup' {
        It 'creates the profile file when it does not exist' {
            $result = Invoke-InstallPs1 -TestRoot $TestRoot

            $result.Status | Should -Be 0
            Test-Path $result.Profile | Should -Be $true
        }

        It 'adds shell function to a fresh profile' {
            $result = Invoke-InstallPs1 -TestRoot $TestRoot

            $content = Get-Content $result.Profile -Raw
            $content | Should -Match '# git-cd BEGIN'
            $content | Should -Match 'function git'
            $content | Should -Match '# git-cd END'
        }

        It 'installed shell function uses @(if...) array wrapping to avoid char-by-char splatting' {
            $result = Invoke-InstallPs1 -TestRoot $TestRoot

            $content = Get-Content $result.Profile -Raw
            $content | Should -Match ([regex]::Escape('@(if ($args.Length -gt 1)'))
        }

        It 'replaces old shell function in profile when it already exists' {
            $oldFunction = @'
# git-cd BEGIN
function git {
    if ($args[0] -eq 'cd') {
        $rest = if ($args.Length -gt 1) { $args[1..($args.Length - 1)] } else { @() }
        $dir = & git-cd @rest
        if ($dir) { Set-Location $dir }
    } else {
        & (Get-Command git -CommandType Application) @args
    }
}
# git-cd END
'@
            $result = Invoke-InstallPs1 -TestRoot $TestRoot -ExistingProfileContent $oldFunction

            $result.Status | Should -Be 0
            $content = Get-Content $result.Profile -Raw
            $content | Should -Match ([regex]::Escape('@(if ($args.Length -gt 1)'))
            $content | Should -Not -Match ([regex]::Escape('$rest = if ($args.Length -gt 1) { $args['))
        }

        It 'does not duplicate shell function when run twice' {
            Invoke-InstallPs1 -TestRoot $TestRoot | Out-Null
            Invoke-InstallPs1 -TestRoot $TestRoot | Out-Null

            $content = Get-Content (Join-Path $TestRoot 'ps-profile.ps1') -Raw
            ([regex]::Matches($content, '# git-cd BEGIN')).Count | Should -Be 1
        }
    }
}
