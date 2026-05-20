$ErrorActionPreference = "Stop"

Describe "bin/ael.ps1" {
BeforeAll {
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Wrapper = Join-Path $RepoRoot "bin\ael.ps1"
$PowerShellExe = if (Get-Command powershell.exe -ErrorAction SilentlyContinue) { (Get-Command powershell.exe).Source } else { (Get-Command pwsh).Source }

function Invoke-AelPs1 {
  param(
    [string[]]$Arguments = @(),
    [string]$WorkingDirectory = $RepoRoot,
    [string]$InputText = $null,
    [hashtable]$Environment = @{}
  )

  $oldValues = @{}
  foreach ($key in $Environment.Keys) {
    $oldValues[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
    [Environment]::SetEnvironmentVariable($key, [string]$Environment[$key], "Process")
  }
  try {
    Push-Location $WorkingDirectory
    try {
      if ($null -ne $InputText) {
        $output = $InputText | & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Wrapper @Arguments 2>&1 | Out-String
      } else {
        $output = & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $Wrapper @Arguments 2>&1 | Out-String
      }
      [pscustomobject]@{
        Output = $output
        Status = $LASTEXITCODE
      }
    } finally {
      Pop-Location
    }
  } finally {
    foreach ($key in $Environment.Keys) {
      [Environment]::SetEnvironmentVariable($key, $oldValues[$key], "Process")
    }
  }
}

}

  It "prints the Windows wrapper version" {
    $result = Invoke-AelPs1 -Arguments @("--version")
    $result.Status | Should -Be 0
    $result.Output.Trim() | Should -Be "AEL 0.3.0 (aiplus 0.6.19+)"
  }

  It "shows all public commands and role shortcuts without substrate branding" {
    $result = Invoke-AelPs1 -Arguments @("--help")
    $result.Status | Should -Be 0
    foreach ($command in @("install", "update", "uninstall", "chat", "talk", "route", "status", "doctor", "telemetry", "invite", "dismiss", "integrate")) {
      $result.Output | Should -Match "ael $command"
    }
    foreach ($role in @("pi", "advisor", "writer", "ra-stata", "ra-python", "theorist", "referee", "replicator", "pm")) {
      $result.Output | Should -Match "ael $role"
    }
    $result.Output | Should -Not -Match "\bAiPlus\b|\baiplus\b|\bAIPLUS\b"
    $result.Output | Should -Not -Match "AEL_BYPASS"
  }

  It "resumes interactive talk by default and honors --fresh" {
    $project = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    $fakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $project ".aiplus"), $fakeBin | Out-Null
    Set-Content -LiteralPath (Join-Path $project ".aiplus\manifest.json") -Value '{"runtimeAdapters":["claude-code"]}' -Encoding UTF8

    $isWindowsPlatform = [System.IO.Path]::DirectorySeparatorChar -eq "\"
    if ($isWindowsPlatform) {
      $runtime = Join-Path $fakeBin "claude.cmd"
      Set-Content -LiteralPath $runtime -Value "@echo off`r`nexit /b 0`r`n" -Encoding ASCII
      $support = Join-Path $fakeBin "ael-support.cmd"
      Set-Content -LiteralPath $support -Value "@echo off`r`necho %* > %AEL_SUPPORT_LOG%`r`nexit /b 0`r`n" -Encoding ASCII
    } else {
      $runtime = Join-Path $fakeBin "claude"
      Set-Content -LiteralPath $runtime -Value "#!/usr/bin/env bash`nexit 0`n" -Encoding ASCII
      chmod +x $runtime
      $support = Join-Path $fakeBin "ael-support"
      Set-Content -LiteralPath $support -Value "#!/usr/bin/env bash`nprintf '%s\n' ""`$*"" >""`$AEL_SUPPORT_LOG""`n" -Encoding ASCII
      chmod +x $support
    }

    $log = Join-Path $fakeBin "support.log"
    $result = Invoke-AelPs1 -Arguments @("talk", "--runtime", "claude-code", "pi") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $log
      PATH = "$fakeBin$([IO.Path]::PathSeparator)$env:PATH"
    }
    $result.Status | Should -Be 0
    (Get-Content -LiteralPath $log -Raw).Trim() | Should -Be "agent talk --resume --runtime claude-code pi"

    $freshLog = Join-Path $fakeBin "support-fresh.log"
    $fresh = Invoke-AelPs1 -Arguments @("talk", "--runtime", "claude-code", "pi", "--fresh") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $freshLog
      PATH = "$fakeBin$([IO.Path]::PathSeparator)$env:PATH"
    }
    $fresh.Status | Should -Be 0
    (Get-Content -LiteralPath $freshLog -Raw).Trim() | Should -Be "agent talk --runtime claude-code pi"

    $shortcutFreshLog = Join-Path $fakeBin "support-shortcut-fresh.log"
    $shortcutFresh = Invoke-AelPs1 -Arguments @("pi", "--fresh") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $shortcutFreshLog
      PATH = "$fakeBin$([IO.Path]::PathSeparator)$env:PATH"
    }
    $shortcutFresh.Status | Should -Be 0
    (Get-Content -LiteralPath $shortcutFreshLog -Raw).Trim() | Should -Be "agent talk --runtime claude-code pi"

    $naturalLanguageLog = Join-Path $fakeBin "support-natural-language.log"
    $naturalLanguage = Invoke-AelPs1 -Arguments @("我想反思 RD 设计") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $naturalLanguageLog
      PATH = "$fakeBin$([IO.Path]::PathSeparator)$env:PATH"
    }
    $naturalLanguage.Status | Should -Be 0
    (Get-Content -LiteralPath $naturalLanguageLog -Raw).Trim() | Should -Be "agent talk --resume --runtime claude-code 我想反思 RD 设计"
  }

  It "routes lobby input by exact slug and natural-language intent" {
    $project = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $project ".aiplus") | Out-Null
    Set-Content -LiteralPath (Join-Path $project ".aiplus\manifest.json") -Value '{"runtimeAdapters":["codex"]}' -Encoding UTF8

    $pi = Invoke-AelPs1 -WorkingDirectory $project -InputText "pi" -Environment @{
      AEL_LOBBY_ROUTE_ONLY = "1"
    }
    $pi.Status | Should -Be 0
    $pi.Output | Should -Match "Core team"
    $pi.Output | Should -Match "-> pi"
    Test-Path (Join-Path $project ".aiplus\agents\.ael-greeted") | Should -Be $true

    $advisor = Invoke-AelPs1 -WorkingDirectory $project -InputText "我想反思 RD 设计" -Environment @{
      AEL_LOBBY_ROUTE_ONLY = "1"
      AEL_NO_ONBOARDING = "1"
    }
    $advisor.Status | Should -Be 0
    $advisor.Output | Should -Match "-> advisor"
    $advisor.Output | Should -Not -Match "\bAiPlus\b|\bAIPLUS\b"
  }
}
