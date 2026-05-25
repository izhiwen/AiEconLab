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
    foreach ($command in @("install", "update", "uninstall", "talk", "route", "status", "doctor")) {
      $result.Output | Should -Match "ael $command"
    }
    foreach ($hiddenCommand in @("chat", "telemetry", "invite", "dismiss", "integrate", "substrate")) {
      $result.Output | Should -Not -Match "ael $hiddenCommand"
    }
    foreach ($role in @("pi", "advisor", "writer", "ra-stata", "ra-python", "theorist", "referee", "replicator", "pm")) {
      $result.Output | Should -Match "ael $role"
    }
    $result.Output | Should -Not -Match "\bAiPlus\b|\baiplus\b|\bAIPLUS\b"
    $result.Output | Should -Not -Match "AEL_BYPASS"
  }

  It "reports telemetry as removed" {
    $result = Invoke-AelPs1 -Arguments @("telemetry", "status")
    $result.Status | Should -Not -Be 0
    $result.Output | Should -Match "ael telemetry has been removed"
  }

  It "rejects accidental multi-argument command paths" {
    $result = Invoke-AelPs1 -Arguments @("foo", "bar", "baz")
    $result.Status | Should -Not -Be 0
    $result.Output | Should -Match "unknown command or multi-word natural-language input"
    $result.Output | Should -Match 'ael "\.\.\."'
  }

  It "keeps chat as a no-argument lobby alias only" {
    $result = Invoke-AelPs1 -Arguments @("chat", "advisor")
    $result.Status | Should -Not -Be 0
    $result.Output | Should -Match "ael chat does not accept arguments"
    $result.Output | Should -Match 'ael "\.\.\."'
  }

  It "delegates talk, role shortcuts, and freeform input like the Unix wrapper" {
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
    (Get-Content -LiteralPath $log -Raw).Trim() | Should -Be "agent talk --runtime claude-code pi"

    $freshLog = Join-Path $fakeBin "support-fresh.log"
    $fresh = Invoke-AelPs1 -Arguments @("talk", "--runtime", "claude-code", "pi", "--fresh") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $freshLog
      PATH = "$fakeBin$([IO.Path]::PathSeparator)$env:PATH"
    }
    $fresh.Status | Should -Be 0
    (Get-Content -LiteralPath $freshLog -Raw).Trim() | Should -Be "agent talk --runtime claude-code pi --fresh"

    $shortcutLog = Join-Path $fakeBin "support-shortcut.log"
    $shortcut = Invoke-AelPs1 -Arguments @("pi") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $shortcutLog
      PATH = "$fakeBin$([IO.Path]::PathSeparator)$env:PATH"
    }
    $shortcut.Status | Should -Be 0
    (Get-Content -LiteralPath $shortcutLog -Raw).Trim() | Should -Be "agent talk --resume pi"

    $shortcutFreshLog = Join-Path $fakeBin "support-shortcut-fresh.log"
    $shortcutFresh = Invoke-AelPs1 -Arguments @("pi", "--fresh") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $shortcutFreshLog
      PATH = "$fakeBin$([IO.Path]::PathSeparator)$env:PATH"
    }
    $shortcutFresh.Status | Should -Be 0
    (Get-Content -LiteralPath $shortcutFreshLog -Raw).Trim() | Should -Be "agent talk pi"

    $naturalLanguageLog = Join-Path $fakeBin "support-natural-language.log"
    $naturalLanguage = Invoke-AelPs1 -Arguments @("我想反思 RD 设计") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $naturalLanguageLog
      PATH = "$fakeBin$([IO.Path]::PathSeparator)$env:PATH"
    }
    $naturalLanguage.Status | Should -Be 0
    (Get-Content -LiteralPath $naturalLanguageLog -Raw).Trim() | Should -Be "agent talk 我想反思 RD 设计"
  }

  It "delegates lobby and chat alias to substrate" {
    $project = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    $fakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $project ".aiplus"), $fakeBin | Out-Null
    Set-Content -LiteralPath (Join-Path $project ".aiplus\manifest.json") -Value '{"runtimeAdapters":["codex"]}' -Encoding UTF8

    $isWindowsPlatform = [System.IO.Path]::DirectorySeparatorChar -eq "\"
    if ($isWindowsPlatform) {
      $support = Join-Path $fakeBin "ael-support.cmd"
      Set-Content -LiteralPath $support -Value "@echo off`r`nif ""%*""=="""" (`r`n  type nul > ""%AEL_SUPPORT_LOG%""`r`n) else (`r`n  echo %* > ""%AEL_SUPPORT_LOG%""`r`n)`r`nexit /b 0`r`n" -Encoding ASCII
    } else {
      $support = Join-Path $fakeBin "ael-support"
      Set-Content -LiteralPath $support -Value "#!/usr/bin/env bash`nprintf '%s\n' ""`$*"" >""`$AEL_SUPPORT_LOG""`n" -Encoding ASCII
      chmod +x $support
    }

    $lobbyLog = Join-Path $fakeBin "support-lobby.log"
    $lobby = Invoke-AelPs1 -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $lobbyLog
      AEL_NO_ONBOARDING = "1"
    }
    $lobby.Status | Should -Be 0
    (Get-Content -LiteralPath $lobbyLog -Raw).Trim() | Should -Be ""

    $chatLog = Join-Path $fakeBin "support-chat.log"
    $chat = Invoke-AelPs1 -Arguments @("chat") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $chatLog
      AEL_NO_ONBOARDING = "1"
    }
    $chat.Status | Should -Be 0
    (Get-Content -LiteralPath $chatLog -Raw).Trim() | Should -Be ""
  }

  It "installs all runtimes in sequence" {
    $project = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    $fakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $project, $fakeBin | Out-Null

    $isWindowsPlatform = [System.IO.Path]::DirectorySeparatorChar -eq "\"
    if ($isWindowsPlatform) {
      $support = Join-Path $fakeBin "ael-support.cmd"
      Set-Content -LiteralPath $support -Value "@echo off`r`necho %*>>%AEL_SUPPORT_LOG%`r`nexit /b 0`r`n" -Encoding ASCII
    } else {
      $support = Join-Path $fakeBin "ael-support"
      Set-Content -LiteralPath $support -Value "#!/usr/bin/env bash`nprintf '%s\n' ""`$*"" >>""`$AEL_SUPPORT_LOG""`n" -Encoding ASCII
      chmod +x $support
    }

    $log = Join-Path $fakeBin "install-all.log"
    $result = Invoke-AelPs1 -Arguments @("install", "all") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
      AEL_SUPPORT_LOG = $log
      AEL_NO_ONBOARDING = "1"
    }
    $result.Status | Should -Be 0
    $result.Output | Should -Match "AEL install runtime=codex status=PASS"
    $result.Output | Should -Match "AEL install runtime=claude-code status=PASS"
    $result.Output | Should -Match "AEL install runtime=opencode status=PASS"
    $result.Output | Should -Match "AEL installed: codex PASS, claude-code PASS, opencode PASS"

    $calls = Get-Content -LiteralPath $log
    $calls | Should -Contain "install codex --allow-version-skew"
    $calls | Should -Contain "install claude-code --allow-version-skew"
    $calls | Should -Contain "install opencode --allow-version-skew"
    ($calls | Where-Object { $_ -eq "add aieconlab" }).Count | Should -Be 3
    ($calls | Where-Object { $_ -eq "agent set-team aieconlab" }).Count | Should -Be 3
    $calls | Should -Contain "mcp-register --runtime codex"
    $calls | Should -Contain "mcp-register --runtime claude-code"
    $calls | Should -Contain "mcp-register --runtime opencode"
  }

  It "flags default SWE consultant config under an AEL project" {
    $project = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    $fakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $project ".aiplus"), $fakeBin | Out-Null
    Set-Content -LiteralPath (Join-Path $project ".aiplus\manifest.json") -Value '{"runtimeAdapters":["codex"],"modules":{"aieconlab":{"version":"test"}}}' -Encoding UTF8

    $isWindowsPlatform = [System.IO.Path]::DirectorySeparatorChar -eq "\"
    if ($isWindowsPlatform) {
      $support = Join-Path $fakeBin "ael-support.cmd"
      Set-Content -LiteralPath $support -Value "@echo off`r`necho DOCTOR_STATUS=PASS`r`nexit /b 0`r`n" -Encoding ASCII
    } else {
      $support = Join-Path $fakeBin "ael-support"
      Set-Content -LiteralPath $support -Value "#!/usr/bin/env bash`nprintf 'DOCTOR_STATUS=PASS\n'`n" -Encoding ASCII
      chmod +x $support
    }

    Copy-Item -LiteralPath (Join-Path $RepoRoot "core\templates\consultant-team.aieconlab.toml") -Destination (Join-Path $project ".aiplus\consultant-team.toml") -Force
    $aelConfig = Invoke-AelPs1 -Arguments @("doctor") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
    }
    $aelConfig.Status | Should -Be 0
    $aelConfig.Output | Should -Match "PASS ael_consultant_team_research_config"

    Set-Content -LiteralPath (Join-Path $project ".aiplus\consultant-team.toml") -Value @'
schema_version = "0.1"

[[members]]
id = "product_market"

[[members]]
id = "ai_integration"

[owner_gates]
push = true

[user_evidence]
enabled = true
'@ -Encoding UTF8
    $defaultConfig = Invoke-AelPs1 -Arguments @("doctor") -WorkingDirectory $project -Environment @{
      AEL_AIPLUS_BIN = $support
    }
    $defaultConfig.Status | Should -Not -Be 0
    $defaultConfig.Output | Should -Match "NEEDS_FIX ael_consultant_team_mismatch"
  }
}
