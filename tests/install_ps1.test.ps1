$ErrorActionPreference = "Stop"

Describe "install.ps1" {
BeforeAll {
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Installer = Join-Path $RepoRoot "install.ps1"
$PowerShellExe = if (Get-Command powershell.exe -ErrorAction SilentlyContinue) { (Get-Command powershell.exe).Source } else { (Get-Command pwsh).Source }

function Invoke-AelInstaller {
  param(
    [string[]]$Arguments = @(),
    [hashtable]$Environment = @{}
  )

  $oldValues = @{}
  foreach ($key in $Environment.Keys) {
    $oldValues[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
    [Environment]::SetEnvironmentVariable($key, [string]$Environment[$key], "Process")
  }
  try {
    $output = & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Installer @Arguments 2>&1 | Out-String
    [pscustomobject]@{
      Output = $output
      Status = $LASTEXITCODE
    }
  } finally {
    foreach ($key in $Environment.Keys) {
      [Environment]::SetEnvironmentVariable($key, $oldValues[$key], "Process")
    }
  }
}

function New-AelWindowsReleasePackage {
  param([string]$Root)

  $release = Join-Path $Root "release"
  $packageParent = Join-Path $Root "pkg"
  $packageName = "ael-v9.9.9-windows-x86_64"
  $package = Join-Path $packageParent $packageName
  New-Item -ItemType Directory -Force -Path (Join-Path $package "bin"), (Join-Path $package "libexec"), $release | Out-Null
	  Set-Content -LiteralPath (Join-Path $package "bin\ael.cmd") -Value "@echo off`r`necho AEL 9.9.9`r`n" -Encoding ASCII
	  Set-Content -LiteralPath (Join-Path $package "bin\ael.ps1") -Value "Write-Host 'AEL 9.9.9'`n" -Encoding ASCII
	  Set-Content -LiteralPath (Join-Path $package "libexec\ael-support.exe") -Value "fake support`n" -Encoding ASCII
	  Set-Content -LiteralPath (Join-Path $package "VERSION") -Value "9.9.9`n" -Encoding ASCII

  $asset = Join-Path $release "$packageName.tar.gz"
  & tar -C $packageParent -czf $asset $packageName
  if ($LASTEXITCODE -ne 0) { throw "tar failed with exit code $LASTEXITCODE" }
  $hash = (Get-FileHash -LiteralPath $asset -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-Content -LiteralPath "$asset.sha256" -Value "$hash  $(Split-Path -Leaf $asset)`n" -Encoding ASCII
  return $release
}

}

  It "resolves a latest version redirect in dry-run mode" {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $result = Invoke-AelInstaller -Arguments @("-DryRun") -Environment @{
      AEL_TEST_LATEST_EFFECTIVE_URL = "https://github.com/izhiwen/AiEconLab/releases/tag/v9.9.9"
      AEL_INSTALL_DIR = (Join-Path $tmp "bin")
      AEL_LIBEXEC_DIR = (Join-Path $tmp "libexec")
    }
    $result.Status | Should -Be 0
    $result.Output | Should -Match "version=v9.9.9"
    $result.Output | Should -Match "DRY_RUN=YES"
    Test-Path (Join-Path $tmp "bin") | Should -Be $false
  }

  It "falls back to the minimum supported version when latest lookup fails" {
    $result = Invoke-AelInstaller -Arguments @("-DryRun") -Environment @{
      AEL_RELEASES_LATEST_URL = "http://127.0.0.1:9/releases/latest"
      AEL_MINIMUM_SUPPORTED_VERSION = "v0.2.3"
    }
    $result.Status | Should -Be 0
    $result.Output | Should -Match "falling back to v0.2.3"
    $result.Output | Should -Match "version=v0.2.3"
  }

  It "installs from a verified local package and prints a manual PATH command" {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $release = New-AelWindowsReleasePackage $tmp
    $install = Join-Path $tmp "install\bin"
    $libexec = Join-Path $tmp "install\libexec"

    $result = Invoke-AelInstaller -Environment @{
      AEL_VERSION = "v9.9.9"
      AEL_BASE_URL = ([System.Uri]$release).AbsoluteUri
      AEL_INSTALL_DIR = $install
      AEL_LIBEXEC_DIR = $libexec
      Path = "$env:SystemRoot\System32"
    }

    $result.Status | Should -Be 0
    $result.Output | Should -Match "SHA256_STATUS=PASS"
    $result.Output | Should -Match "INSTALL_STATUS=PASS"
    $result.Output | Should -Match "PATH_NOTICE="
    $result.Output | Should -Match "cd MyProject"
	    Test-Path (Join-Path $install "ael.cmd") | Should -Be $true
	    Test-Path (Join-Path $install "ael.ps1") | Should -Be $true
	    Test-Path (Join-Path $libexec "ael-support.exe") | Should -Be $true
	    Test-Path (Join-Path (Split-Path -Parent $install) "VERSION") | Should -Be $true
	  }

  It "reports AddToPath intent during dry-run without editing PATH" {
    $result = Invoke-AelInstaller -Arguments @("-DryRun", "-AddToPath") -Environment @{
      AEL_VERSION = "v9.9.9"
    }
    $result.Status | Should -Be 0
    $result.Output | Should -Match "add_to_path=would_update_user_path_if_needed"
  }
}
