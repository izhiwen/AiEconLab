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
    $result.Output.Trim() | Should -Be "AEL 0.2.3"
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
