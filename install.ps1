param(
  [switch]$AddToPath,
  [switch]$DryRun,
  [switch]$Help
)

$ErrorActionPreference = "Stop"

$Repo = if ($env:AEL_REPO) { $env:AEL_REPO } else { "izhiwen/AiEconLab" }
$MinimumSupported = if ($env:AEL_MINIMUM_SUPPORTED_VERSION) { $env:AEL_MINIMUM_SUPPORTED_VERSION } else { "v0.2.3" }
$LatestUrl = if ($env:AEL_RELEASES_LATEST_URL) { $env:AEL_RELEASES_LATEST_URL } else { "https://github.com/$Repo/releases/latest" }
$VersionOverride = $env:AEL_VERSION
$BaseLocal = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $env:USERPROFILE "AppData\Local" }
$InstallDir = if ($env:AEL_INSTALL_DIR) { $env:AEL_INSTALL_DIR } else { Join-Path $BaseLocal "Programs\AEL\bin" }
$LibexecDir = if ($env:AEL_LIBEXEC_DIR) { $env:AEL_LIBEXEC_DIR } else { Join-Path $BaseLocal "Programs\AEL\libexec" }

function Show-Usage {
  @"
Install the ael command.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 [-DryRun] [-AddToPath]

Environment:
  AEL_VERSION      Release version to install, default latest GitHub release
  AEL_INSTALL_DIR  Install directory for ael.cmd and ael.ps1
  AEL_LIBEXEC_DIR  Install directory for bundled runtime support
  AEL_BASE_URL     Override release base URL for tests/mirrors

Flags:
  -DryRun          Print what would happen without writing
  -AddToPath       Append the install directory to the user PATH if needed
  -Help            Show this help

The installer downloads the AEL release package for Windows, verifies the
package SHA256 sidecar, and installs:
  - ael.cmd and ael.ps1 to the install directory
  - bundled runtime support to the libexec directory

It does not require administrator rights, install project files, upload data,
collect telemetry, or modify runtime config. It edits PATH only when -AddToPath
is set.
"@
}

function Normalize-Version([string]$Value) {
  if ($Value.StartsWith("v")) { return $Value }
  return "v$Value"
}

function Parse-Version-From-Url([string]$Url) {
  if ($Url -match "/tag/(v?[0-9][^/?#]*)") {
    return (Normalize-Version $Matches[1])
  }
  return $null
}

function Resolve-Version {
  if ($VersionOverride) {
    return (Normalize-Version $VersionOverride)
  }

  if ($env:AEL_TEST_LATEST_EFFECTIVE_URL) {
    $parsed = Parse-Version-From-Url $env:AEL_TEST_LATEST_EFFECTIVE_URL
    if ($parsed) { return $parsed }
  }

  try {
    $request = [System.Net.WebRequest]::Create($LatestUrl)
    $request.Method = "HEAD"
    $request.AllowAutoRedirect = $true
    $response = $request.GetResponse()
    try {
      $parsed = Parse-Version-From-Url $response.ResponseUri.AbsoluteUri
      if ($parsed) { return $parsed }
    } finally {
      $response.Close()
    }
  } catch {
    Write-Warning "could not resolve latest AEL release; falling back to $MinimumSupported"
    return (Normalize-Version $MinimumSupported)
  }

  Write-Warning "could not resolve latest AEL release; falling back to $MinimumSupported"
  return (Normalize-Version $MinimumSupported)
}

function Get-Asset-Name([string]$Version) {
  $versionNoV = $Version.TrimStart("v")
  return "ael-v$versionNoV-windows-x86_64.tar.gz"
}

function Copy-Url([string]$Source, [string]$Destination) {
  if ($Source -match "^file://") {
    $localPath = ([System.Uri]$Source).LocalPath
    Copy-Item -LiteralPath $localPath -Destination $Destination -Force
    return
  }
  Invoke-WebRequest -Uri $Source -OutFile $Destination -UseBasicParsing
}

function Sanitize-SubstrateOutput([string]$Text) {
  $Text = $Text -replace "(?<![./-])\bAiPlus\b", "AEL"
  $Text = $Text -replace "(?<![./-])\baiplus\b", "ael"
  $Text = $Text -replace "(?<![./-])\bAIPLUS\b", "AEL"
  return $Text
}

function Test-Sha256([string]$Sidecar, [string]$Asset) {
  $expected = ((Get-Content -LiteralPath $Sidecar -TotalCount 1) -split "\s+")[0]
  if (-not $expected) {
    throw "checksum sidecar is empty: $Sidecar"
  }
  $actual = (Get-FileHash -LiteralPath $Asset -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected.ToLowerInvariant()) {
    throw "checksum mismatch for $(Split-Path -Leaf $Asset): expected $expected actual $actual"
  }
  Write-Host "SHA256_STATUS=PASS"
}

function Test-PathEntry([string]$PathValue, [string]$Entry) {
  if (-not $PathValue) { return $false }
  $target = $Entry.TrimEnd("\")
  foreach ($part in ($PathValue -split ";")) {
    if ($part.TrimEnd("\").Equals($target, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Escape-SingleQuoted([string]$Value) {
  return $Value.Replace("'", "''")
}

function Show-Manual-PathCommand([string]$Dir) {
  $escaped = Escape-SingleQuoted $Dir
  Write-Host "PATH_NOTICE=$Dir is not on PATH"
  Write-Host "Run this PowerShell command if you want to run ael from any terminal:"
  Write-Host "  `$p=[Environment]::GetEnvironmentVariable('Path','User'); if (-not ((`$p -split ';') -contains '$escaped')) { [Environment]::SetEnvironmentVariable('Path', ((`$p.TrimEnd(';') + ';$escaped').Trim(';')), 'User') }"
}

function Send-EnvironmentBroadcast {
  if ($env:AEL_SKIP_PATH_BROADCAST -eq "1") { return }
  $signature = @"
using System;
using System.Runtime.InteropServices;
public static class AelEnvironmentBroadcast {
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
  try {
    Add-Type -TypeDefinition $signature -ErrorAction SilentlyContinue | Out-Null
    $result = [UIntPtr]::Zero
    [AelEnvironmentBroadcast]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, "Environment", 0x2, 5000, [ref]$result) | Out-Null
  } catch {
    Write-Warning "PATH was updated, but broadcasting the environment change failed. Open a new terminal if ael is not found."
  }
}

function Add-InstallDir-ToPath([string]$Dir) {
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (Test-PathEntry $userPath $Dir) {
    Write-Host "PATH_USER_ALREADY_CONFIGURED=$Dir"
    return
  }

  $newPath = if ($userPath) { ($userPath.TrimEnd(";") + ";$Dir") } else { $Dir }
  [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
  $env:Path = if ($env:Path) { "$env:Path;$Dir" } else { $Dir }
  Send-EnvironmentBroadcast
  Write-Host "PATH_USER_APPENDED=$Dir"
  Write-Host "Open a new terminal, then run: ael"
}

if ($Help) {
  Show-Usage
  exit 0
}

$Version = Resolve-Version
$Asset = Get-Asset-Name $Version
$BaseUrl = if ($env:AEL_BASE_URL) { $env:AEL_BASE_URL.TrimEnd("/") } else { "https://github.com/$Repo/releases/download/$Version" }

Write-Host "AEL installer"
Write-Host "version=$Version"
Write-Host "asset=$Asset"
Write-Host "install_dir=$InstallDir"
Write-Host "libexec_dir=$LibexecDir"
Write-Host "writes=$InstallDir\ael.cmd"
Write-Host "path_edits=$(if ($AddToPath) { 'opt-in' } else { 'none' })"
Write-Host "telemetry=none"

if ($DryRun) {
  Write-Host "DRY_RUN=YES"
  Write-Host "download=$BaseUrl/$Asset"
  Write-Host "checksum=$BaseUrl/$Asset.sha256"
  if ($AddToPath) {
    Write-Host "add_to_path=would_update_user_path_if_needed"
  }
  exit 0
}

$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ael-install-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
try {
  $AssetPath = Join-Path $TempDir $Asset
  $SidecarPath = Join-Path $TempDir "$Asset.sha256"
  Copy-Url "$BaseUrl/$Asset.sha256" $SidecarPath
  Copy-Url "$BaseUrl/$Asset" $AssetPath
  Test-Sha256 $SidecarPath $AssetPath

  $ExtractDir = Join-Path $TempDir "extract"
  New-Item -ItemType Directory -Force -Path $ExtractDir | Out-Null
  & tar -xzf $AssetPath -C $ExtractDir
  if ($LASTEXITCODE -ne 0) {
    throw "tar extraction failed with exit code $LASTEXITCODE"
  }

  $Cmd = Get-ChildItem -LiteralPath $ExtractDir -Recurse -File -Filter "ael.cmd" | Select-Object -First 1
  $Ps1 = Get-ChildItem -LiteralPath $ExtractDir -Recurse -File -Filter "ael.ps1" | Select-Object -First 1
  $Support = Get-ChildItem -LiteralPath $ExtractDir -Recurse -File -Filter "ael-support.exe" | Select-Object -First 1
  if (-not $Cmd) { throw "release archive did not contain bin/ael.cmd" }
  if (-not $Ps1) { throw "release archive did not contain bin/ael.ps1" }
  if (-not $Support) { throw "release archive did not contain libexec/ael-support.exe" }

  New-Item -ItemType Directory -Force -Path $InstallDir, $LibexecDir | Out-Null
  Copy-Item -LiteralPath $Cmd.FullName -Destination (Join-Path $InstallDir "ael.cmd") -Force
  Copy-Item -LiteralPath $Ps1.FullName -Destination (Join-Path $InstallDir "ael.ps1") -Force
  Copy-Item -LiteralPath $Support.FullName -Destination (Join-Path $LibexecDir "ael-support.exe") -Force

  Write-Host "INSTALL_STATUS=PASS"
  Write-Host "installed=$InstallDir\ael.cmd"

  if (-not (Test-PathEntry $env:Path $InstallDir)) {
    if ($AddToPath) {
      Add-InstallDir-ToPath $InstallDir
    } else {
      Show-Manual-PathCommand $InstallDir
    }
  }

  Write-Host "Next:"
  Write-Host "  cd MyProject"
  Write-Host "  ael install                  # once per project - sets up the research team"
  Write-Host "  ael                          # opens the lobby - pick who to talk to (PI, Advisor, writer, ...)"
  Write-Host "  ael advisor                  # or jump straight to advisor"
  Write-Host "  ael pi                       # or straight to PI"
} finally {
  Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
