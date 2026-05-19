$ErrorActionPreference = "Stop"

$script:AelVersion = if ($env:AEL_VERSION) { $env:AEL_VERSION.TrimStart("v") } else { "0.2.3" }
$script:AelRepo = if ($env:AEL_REPO) { $env:AEL_REPO } else { "izhiwen/AiEconLab" }
$script:MinimumSupported = if ($env:AEL_MINIMUM_SUPPORTED_VERSION) { $env:AEL_MINIMUM_SUPPORTED_VERSION } else { "v0.2.3" }
$script:BinDir = Split-Path -Parent $PSCommandPath
$script:AelRoot = $script:BinDir
if (Test-Path (Join-Path (Split-Path -Parent $script:BinDir) "libexec")) {
  $script:AelRoot = Split-Path -Parent $script:BinDir
}

function Write-AelError([string]$Message) {
  [Console]::Error.WriteLine("ael: $Message")
}

function Write-AelOut([string]$Text = "") {
  Write-Output $Text
}

function Write-AelRaw([string]$Text) {
  Write-Output $Text
}

function Exit-WithError([string]$Message, [int]$Code = 1) {
  Write-AelError $Message
  exit $Code
}

function Sanitize-Text([string]$Text) {
  $Text = $Text -replace "(?<![./-])\bAiPlus\b", "AEL"
  $Text = $Text -replace "(?<![./-])\baiplus\b", "ael"
  $Text = $Text -replace "(?<![./-])\bAIPLUS\b", "AEL"
  return $Text
}

function Write-SanitizedObject($Object) {
  if ($null -ne $Object) {
    Write-AelOut (Sanitize-Text ([string]$Object))
  }
}

function Show-Usage {
  $text = @"
AEL $script:AelVersion

Usage:
  ael install [codex|claude-code|opencode|all]   set up the research team here (once per project)
  ael update [--dry-run]                          update the installed ael CLI
  ael uninstall [--purge] [--yes]                 remove the installed ael CLI
  ael                                             open the lobby - pick or describe who you want to talk to
  ael chat                                        open the same lobby explicitly
  ael <role>                                      shortcut: directly start a chat with that role
  ael status                                      show installed team + active runtime
  ael doctor [--fix]                              self-check and fix common drift

Roles you can chat with directly:
  ael pi                                          项目经理 - 派单、跟进、汇总
  ael advisor                                     顾问 - 反思、识别策略、框架
  ael writer                                      写手 - 起草段落、引言、改稿
  ael ra-stata                                    实证 RA - 回归、表格、Stata
  ael ra-python                                   数据 RA - 清洗、合并、Python
  ael theorist                                    理论 - 识别假设、模型
  ael referee                                     内审 - 内部自审
  ael replicator                                  复现 - clean-room 复跑
  ael pm                                          项目管理 - Gantt、deadline

Advanced:
  ael talk [--runtime RUNTIME] <role> [prompt...]
  ael route <role> <task...>
  ael telemetry [enable|disable|status]
  ael invite <role>
  ael dismiss <role>
  ael integrate <role>
  ael update [--dry-run]
  ael uninstall [--purge] [--yes]
  ael --version

Recommended flow:
  ael install
  ael
  ael pi
  ael advisor
"@
  Write-AelOut $text
}

function Get-InstallDir {
  if ($env:AEL_INSTALL_DIR) { return $env:AEL_INSTALL_DIR }
  if ($env:LOCALAPPDATA) { return (Join-Path $env:LOCALAPPDATA "Programs\AEL\bin") }
  return (Join-Path $env:USERPROFILE "AppData\Local\Programs\AEL\bin")
}

function Get-LibexecDir {
  if ($env:AEL_LIBEXEC_DIR) { return $env:AEL_LIBEXEC_DIR }
  if ($env:LOCALAPPDATA) { return (Join-Path $env:LOCALAPPDATA "Programs\AEL\libexec") }
  return (Join-Path $env:USERPROFILE "AppData\Local\Programs\AEL\libexec")
}

function Normalize-Version([string]$Value) {
  if ($Value.StartsWith("v")) { return $Value.TrimStart("v") }
  return $Value
}

function Parse-Version-From-Url([string]$Url) {
  if ($Url -match "/tag/(v?[0-9][^/?#]*)") {
    return (Normalize-Version $Matches[1])
  }
  return $null
}

function Get-LatestReleaseVersion {
  if ($env:AEL_UPDATE_LATEST_VERSION) {
    return (Normalize-Version $env:AEL_UPDATE_LATEST_VERSION)
  }
  if ($env:AEL_TEST_LATEST_EFFECTIVE_URL) {
    $parsed = Parse-Version-From-Url $env:AEL_TEST_LATEST_EFFECTIVE_URL
    if ($parsed) { return $parsed }
  }
  $latestUrl = if ($env:AEL_RELEASES_LATEST_URL) { $env:AEL_RELEASES_LATEST_URL } else { "https://github.com/$script:AelRepo/releases/latest" }
  try {
    $request = [System.Net.WebRequest]::Create($latestUrl)
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
    Exit-WithError "could not resolve latest AEL release"
  }
  Exit-WithError "could not parse latest AEL release"
}

function Get-CurrentInstalledVersion {
  $installed = Join-Path (Get-InstallDir) "ael.ps1"
  $versionOut = ""
  if (Test-Path $installed) {
    $versionOut = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installed --version 2>$null | Select-Object -First 1)
  }
  if (-not $versionOut) {
    $versionOut = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath --version 2>$null | Select-Object -First 1)
  }
  if ($versionOut -match "^AEL\s+(.+)$") {
    return (Normalize-Version $Matches[1])
  }
  return $null
}

function Get-WindowsAsset([string]$Version) {
  $v = Normalize-Version $Version
  return "ael-v$v-windows-x86_64.tar.gz"
}

function Copy-Url([string]$Source, [string]$Destination) {
  if ($Source -match "^file://") {
    Copy-Item -LiteralPath ([System.Uri]$Source).LocalPath -Destination $Destination -Force
    return
  }
  Invoke-WebRequest -Uri $Source -OutFile $Destination -UseBasicParsing
}

function Test-Sha256([string]$Sidecar, [string]$Asset) {
  $expected = ((Get-Content -LiteralPath $Sidecar -TotalCount 1) -split "\s+")[0]
  if (-not $expected) { Exit-WithError "checksum sidecar is empty: $Sidecar" }
  $actual = (Get-FileHash -LiteralPath $Asset -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected.ToLowerInvariant()) {
    Exit-WithError "checksum mismatch for $(Split-Path -Leaf $Asset)"
  }
}

function Get-SubstrateBin {
  $candidates = @()
  if ($env:AEL_AIPLUS_BIN) { $candidates += $env:AEL_AIPLUS_BIN }
  $candidates += @(
    (Join-Path $script:BinDir "libexec\ael-support.exe"),
    (Join-Path (Split-Path -Parent $script:BinDir) "libexec\ael-support.exe"),
    (Join-Path $script:AelRoot "libexec\ael-support.exe"),
    (Join-Path $script:AelRoot "vendor\aiplus\target\release\aiplus.exe")
  )
  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) { return $candidate }
  }
  Exit-WithError "bundled runtime not built. Install AEL again or run scripts/build-ael.sh."
}

function Invoke-SubstrateQuiet([string[]]$SubArgs) {
  $bin = Get-SubstrateBin
  $tmp = New-TemporaryFile
  try {
    & $bin @SubArgs > $tmp 2>&1
    $status = $LASTEXITCODE
    if ($status -ne 0) {
      Get-Content -LiteralPath $tmp | ForEach-Object { [Console]::Error.WriteLine((Sanitize-Text $_)) }
    }
    return $status
  } finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-SubstrateVisible([string[]]$SubArgs) {
  $bin = Get-SubstrateBin
  & $bin @SubArgs 2>&1 | ForEach-Object { Write-SanitizedObject $_ }
  return $LASTEXITCODE
}

function Invoke-SubstrateInteractive([string[]]$SubArgs) {
  $bin = Get-SubstrateBin
  $process = Start-Process -FilePath $bin -ArgumentList $SubArgs -NoNewWindow -Wait -PassThru
  return $process.ExitCode
}

function Invoke-Update([string[]]$UpdateArgs) {
  $dryRun = $false
  foreach ($arg in $UpdateArgs) {
    switch ($arg) {
      "--dry-run" { $dryRun = $true }
      "-h" { Write-AelOut "Usage: ael update [--dry-run]"; return 0 }
      "--help" { Write-AelOut "Usage: ael update [--dry-run]"; return 0 }
      default { Exit-WithError "usage: ael update [--dry-run]" }
    }
  }

  $latest = Get-LatestReleaseVersion
  $installed = Get-CurrentInstalledVersion
  if (-not $installed) { Exit-WithError "could not determine installed AEL version" }
  if ($installed -eq $latest) {
    Write-AelOut "AEL $installed is already up-to-date"
    return 0
  }

  $asset = Get-WindowsAsset $latest
  $baseUrl = if ($env:AEL_BASE_URL) { $env:AEL_BASE_URL.TrimEnd("/") } else { "https://github.com/$script:AelRepo/releases/download/v$latest" }
  $targetInstall = Get-InstallDir
  $targetLibexec = Get-LibexecDir
  Write-AelOut "AEL $installed -> AEL $latest"
  Write-AelOut "download=$baseUrl/$asset"
  Write-AelOut "install_dir=$targetInstall"
  Write-AelOut "libexec_dir=$targetLibexec"

  if ($dryRun) {
    Write-AelOut "DRY_RUN=YES"
    Write-AelOut "would_verify=$baseUrl/$asset.sha256"
    Write-AelOut "would_replace=$targetInstall\ael.cmd"
    Write-AelOut "would_replace=$targetInstall\ael.ps1"
    Write-AelOut "would_replace=$targetLibexec\ael-support.exe"
    return 0
  }

  $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ael-update-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
  try {
    $assetPath = Join-Path $tmpDir $asset
    $sidecarPath = Join-Path $tmpDir "$asset.sha256"
    Copy-Url "$baseUrl/$asset.sha256" $sidecarPath
    Copy-Url "$baseUrl/$asset" $assetPath
    Test-Sha256 $sidecarPath $assetPath
    $extract = Join-Path $tmpDir "extract"
    New-Item -ItemType Directory -Force -Path $extract | Out-Null
    & tar -xzf $assetPath -C $extract
    if ($LASTEXITCODE -ne 0) { Exit-WithError "tar extraction failed with exit code $LASTEXITCODE" }
    $cmd = Get-ChildItem -LiteralPath $extract -Recurse -File -Filter "ael.cmd" | Select-Object -First 1
    $ps1 = Get-ChildItem -LiteralPath $extract -Recurse -File -Filter "ael.ps1" | Select-Object -First 1
    $support = Get-ChildItem -LiteralPath $extract -Recurse -File -Filter "ael-support.exe" | Select-Object -First 1
    if (-not $cmd) { Exit-WithError "release archive did not contain bin/ael.cmd" }
    if (-not $ps1) { Exit-WithError "release archive did not contain bin/ael.ps1" }
    if (-not $support) { Exit-WithError "release archive did not contain libexec/ael-support.exe" }
    New-Item -ItemType Directory -Force -Path $targetInstall, $targetLibexec | Out-Null
    Copy-Item -LiteralPath $cmd.FullName -Destination (Join-Path $targetInstall "ael.cmd") -Force
    Copy-Item -LiteralPath $ps1.FullName -Destination (Join-Path $targetInstall "ael.ps1") -Force
    Copy-Item -LiteralPath $support.FullName -Destination (Join-Path $targetLibexec "ael-support.exe") -Force
    Write-AelOut "UPDATE_STATUS=PASS"
    Write-AelOut "installed=$targetInstall\ael.cmd"
    return 0
  } finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Confirm-Uninstall([bool]$Purge) {
  $message = "Remove AEL from this machine"
  if ($Purge) { $message += " and purge this project team directory" }
  $answer = Read-Host "$message? [y/N]"
  return ($answer -in @("y", "Y", "yes", "YES"))
}

function Invoke-Uninstall([string[]]$UninstallArgs) {
  $purge = $false
  $yes = $false
  foreach ($arg in $UninstallArgs) {
    switch ($arg) {
      "--purge" { $purge = $true }
      "--yes" { $yes = $true }
      "-y" { $yes = $true }
      "-h" { Write-AelOut "Usage: ael uninstall [--purge] [--yes]"; return 0 }
      "--help" { Write-AelOut "Usage: ael uninstall [--purge] [--yes]"; return 0 }
      default { Exit-WithError "usage: ael uninstall [--purge] [--yes]" }
    }
  }
  if (-not $yes) {
    if (-not (Confirm-Uninstall $purge)) {
      Write-AelOut "UNINSTALL_STATUS=CANCELLED"
      return 1
    }
  }
  $removed = $false
  $install = Get-InstallDir
  $libexec = Get-LibexecDir
  Write-AelOut "AEL uninstall"
  foreach ($target in @((Join-Path $install "ael.cmd"), (Join-Path $install "ael.ps1"), (Join-Path $libexec "ael-support.exe"))) {
    if (Test-Path $target) {
      Remove-Item -LiteralPath $target -Force
      Write-AelOut "removed=$target"
      $removed = $true
    } else {
      Write-AelOut "not_found=$target"
    }
  }
  $projectState = Join-Path (Get-Location) ".aiplus"
  if ($purge -and (Test-Path $projectState)) {
    Remove-Item -LiteralPath $projectState -Recurse -Force
    Write-AelOut "removed=$projectState"
    $removed = $true
  } elseif ($purge) {
    Write-AelOut "not_found=$projectState"
  }
  if (-not $removed) { Write-AelOut "removed=none" }
  if (-not $purge) { Write-AelOut "preserved=$projectState" }
  Write-AelOut "UNINSTALL_STATUS=PASS"
  return 0
}

function Get-TelemetryPath {
  if ($env:AEL_TELEMETRY_PATH) { return $env:AEL_TELEMETRY_PATH }
  return (Join-Path (Get-Location) ".ael\telemetry.json")
}

function Write-TelemetryConfig([bool]$Enabled) {
  $path = Get-TelemetryPath
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
  $payload = [ordered]@{
    schema_version = "v0.2.1"
    enabled = $Enabled
    mode = "local-json"
    hosted_endpoint = $null
    events_path = ".ael/telemetry-events.jsonl"
    updated_at = (Get-Date).ToUniversalTime().ToString("o").Replace("+00:00", "Z")
  }
  $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $path -Encoding UTF8
}

function Get-TelemetryState {
  $path = Get-TelemetryPath
  if (-not (Test-Path $path)) { return "false" }
  try {
    $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($data.enabled -eq $true) { return "true" }
    return "false"
  } catch {
    return "invalid"
  }
}

function Invoke-Telemetry([string[]]$TelemetryArgs) {
  $action = if ($TelemetryArgs.Count -gt 0) { $TelemetryArgs[0] } else { "status" }
  switch ($action) {
    "enable" {
      Write-TelemetryConfig $true
      Write-AelOut "AEL telemetry enabled"
    }
    "disable" {
      Write-TelemetryConfig $false
      Write-AelOut "AEL telemetry disabled"
    }
    "status" {
      $state = Get-TelemetryState
      if ($state -eq "invalid") { Exit-WithError "telemetry config is invalid JSON: $(Get-TelemetryPath)" }
      if ($state -eq "true") { Write-AelOut "AEL telemetry status: enabled" } else { Write-AelOut "AEL telemetry status: disabled" }
    }
    default { Exit-WithError "usage: ael telemetry [enable|disable|status]" }
  }
  Write-AelOut "mode=local-json"
  Write-AelOut "config=$(Get-TelemetryPath)"
  Write-AelOut "hosted_endpoint=none"
  return 0
}

function Show-OnboardingHint {
  if ($env:AEL_NO_ONBOARDING -eq "1") { return }
  $text = @"
Quick start (your team is ready):

  ael                  open the lobby - pick who to talk to (PI / Advisor / ...)
  ael advisor          jump straight to Advisor for paper framing
  ael pi               jump straight to PI for orchestration

Tip: open two terminal windows for the Owner->Advisor + Owner->PI flow
(one window per role).

More: ael --help
"@
  Write-AelOut $text
}

function Get-CommandNameOrDefault([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  return $cmd
}

function Detect-Runtime {
  if ($env:AEL_RUNTIME) { return $env:AEL_RUNTIME }
  if (Get-CommandNameOrDefault "codex") { return "codex" }
  if (Get-CommandNameOrDefault "claude") { return "claude-code" }
  if (Get-CommandNameOrDefault "opencode") { return "opencode" }
  return "codex"
}

function Runtime-FromManifest {
  $path = Join-Path (Get-Location) ".aiplus\manifest.json"
  if (-not (Test-Path $path)) { return "" }
  try {
    $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    foreach ($preferred in @("codex", "claude-code", "opencode")) {
      if ($manifest.runtimeAdapters -contains $preferred) { return $preferred }
    }
  } catch {
    return ""
  }
  return ""
}

function Invoke-Install([string[]]$InstallArgs) {
  $runtime = ""
  $dryRun = $false
  $passArgs = @()
  $i = 0
  while ($i -lt $InstallArgs.Count) {
    $arg = $InstallArgs[$i]
    switch -Regex ($arg) {
      "^(codex|claude-code|opencode|all)$" {
        if (-not $runtime) { $runtime = $arg } else { $passArgs += $arg }
      }
      "^--runtime$" {
        if ($i + 1 -ge $InstallArgs.Count) { Exit-WithError "--runtime requires a value" }
        $i++
        $runtime = $InstallArgs[$i]
      }
      "^--runtime=" {
        $runtime = $arg.Substring("--runtime=".Length)
      }
      "^--dry-run$" {
        $dryRun = $true
        $passArgs += $arg
      }
      default {
        $passArgs += $arg
      }
    }
    $i++
  }
  if (-not $runtime) { $runtime = Detect-Runtime }
  if ($dryRun) {
    Write-AelOut "AEL install dry-run"
    Write-AelOut "  runtime=$runtime"
    Write-AelOut "  would bootstrap the project runtime adapter"
    Write-AelOut "  would install the AiEconLab research team"
    Write-AelOut "  would set AiEconLab as the active team"
    Write-AelOut "  would register the MCP server with $runtime (native tool-use for chat)"
    Write-AelOut "AEL_DRY_RUN=PASS"
    return 0
  }
  $installArgs = @("install", $runtime, "--allow-version-skew") + $passArgs
  $status = Invoke-SubstrateQuiet $installArgs
  if ($status -ne 0) { return $status }
  $status = Invoke-SubstrateQuiet @("add", "aieconlab")
  if ($status -ne 0) { return $status }
  $status = Invoke-SubstrateQuiet @("agent", "set-team", "aieconlab")
  if ($status -ne 0) { return $status }
  $status = Invoke-SubstrateQuiet @("mcp-register", "--runtime", $runtime)
  if ($status -eq 0) {
    Write-AelOut "AEL installed for runtime=$runtime (chat tools registered)"
  } else {
    [Console]::Error.WriteLine("AEL installed for runtime=$runtime (chat tools not registered; fallback active)")
  }
  Write-AelOut "Next: ael                  # chat with your team in plain English / Chinese"
  Show-OnboardingHint
  return 0
}

function Get-PersonaPath([string]$Role) {
  $pwd = (Get-Location).Path
  $candidates = @(
    (Join-Path $pwd ".aiplus\agents\personas\$Role.md"),
    (Join-Path $pwd ".aiplus\agents\personas\_stubs\$Role.md"),
    (Join-Path $pwd ".aiplus\modules\aieconlab\core\templates\personas\$Role.md"),
    (Join-Path $script:AelRoot "core\templates\personas\$Role.md"),
    (Join-Path (Split-Path -Parent $script:AelRoot) "core\templates\personas\$Role.md")
  )
  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) { return $candidate }
  }
  return $null
}

function Get-FallbackPersona([string]$Role) {
  switch ($Role) {
    "advisor" { return "Advisor: research question framing, identification strategy, and paper risk tradeoffs." }
    "pi" { return "PI: research project scope, milestone coordination, dispatch, and artifact integration." }
    "ra-stata" { return "RA-Stata: empirical analysis, regression specifications, datasets, tables, robustness, and Stata reproducibility." }
    "referee" { return "Referee: internal pre-submission review of methodology, argument structure, evidence, coherence, and academic rigor." }
    default { return "${Role}: AiEconLab research role. Follow the installed persona when available." }
  }
}

function Get-CliReferenceContext([string]$Role) {
  if ($Role -notin @("pi", "advisor")) { return "" }
  $path = Join-Path (Get-Location) ".aiplus\modules\aieconlab\core\templates\ael-cli-reference.md"
  if (Test-Path $path) {
    return "Installed AEL CLI reference path: $path"
  }
  return "AEL CLI reference path to consult when installed: $path"
}

function Build-HeadlessPrompt([string]$Role, [string]$RequestText) {
  $personaPath = Get-PersonaPath $Role
  if ($personaPath) {
    $persona = (Get-Content -LiteralPath $personaPath -TotalCount 80 | ForEach-Object { Sanitize-Text $_ }) -join "`n"
  } else {
    $persona = Get-FallbackPersona $Role
  }
  $cliReference = Get-CliReferenceContext $Role
@"
You are the "$Role" role in AiEconLab (AEL), an applied-economics research team.
Stay in this role for the full response. Use the persona below as binding context.
Do not mention implementation substrate details.

Persona:
---
$persona
---

AEL CLI reference:
---
$cliReference
---

User request:
$RequestText

When the user asks what your role is, include the literal text "AiEconLab", the
resolved role name "$Role", and one concrete research responsibility from the persona.
"@
}

function Get-RuntimeBinary([string]$Runtime) {
  switch ($Runtime) {
    "codex" { return "codex" }
    "claude-code" { return "claude" }
    "opencode" { return "opencode" }
    default { Exit-WithError "unknown runtime: $Runtime" }
  }
}

function Invoke-HeadlessTalk([string]$Runtime, [string]$Role, [string]$RequestText) {
  $prompt = Build-HeadlessPrompt $Role $RequestText
  switch ($Runtime) {
    "codex" {
      if (-not (Get-CommandNameOrDefault "codex")) { Exit-WithError "codex CLI not found on PATH" }
      $answer = New-TemporaryFile
      $log = New-TemporaryFile
      try {
        $cmdArgs = @("exec", "--skip-git-repo-check", "--cd", (Get-Location).Path, "--color", "never")
        if ($env:AEL_CODEX_MODEL) { $cmdArgs += @("--model", $env:AEL_CODEX_MODEL) }
        $cmdArgs += @("--output-last-message", $answer.FullName, $prompt)
        & codex @cmdArgs > $log 2>&1
        $status = $LASTEXITCODE
        if ($status -eq 0) {
          Get-Content -LiteralPath $answer.FullName | ForEach-Object { Write-SanitizedObject $_ }
        } else {
          Get-Content -LiteralPath $log.FullName | ForEach-Object { [Console]::Error.WriteLine((Sanitize-Text $_)) }
        }
        return $status
      } finally {
        Remove-Item -LiteralPath $answer.FullName, $log.FullName -Force -ErrorAction SilentlyContinue
      }
    }
    "claude-code" {
      if (-not (Get-CommandNameOrDefault "claude")) { Exit-WithError "claude CLI not found on PATH" }
      $cmdArgs = @("--print", "--dangerously-skip-permissions", "--model", $(if ($env:AEL_CLAUDE_MODEL) { $env:AEL_CLAUDE_MODEL } else { "sonnet" }), $prompt)
      & claude @cmdArgs 2>&1 | ForEach-Object { Write-SanitizedObject $_ }
      return $LASTEXITCODE
    }
    "opencode" {
      if (-not (Get-CommandNameOrDefault "opencode")) { Exit-WithError "opencode CLI not found on PATH" }
      $model = if ($env:AEL_OPENCODE_MODEL) { $env:AEL_OPENCODE_MODEL } else { "openai/gpt-4o" }
      $cmdArgs = @("run", "--dir", (Get-Location).Path, "--model", $model, "--dangerously-skip-permissions", $prompt)
      & opencode @cmdArgs 2>&1 | ForEach-Object { Write-SanitizedObject $_ }
      return $LASTEXITCODE
    }
    default {
      Exit-WithError "unknown runtime: $Runtime"
    }
  }
}

function Invoke-Talk([string[]]$TalkArgs) {
  $runtime = ""
  $i = 0
  while ($i -lt $TalkArgs.Count) {
    $arg = $TalkArgs[$i]
    if ($arg -eq "--runtime") {
      if ($i + 1 -ge $TalkArgs.Count) { Exit-WithError "--runtime requires a value" }
      $i++
      $runtime = $TalkArgs[$i]
    } elseif ($arg -like "--runtime=*") {
      $runtime = $arg.Substring("--runtime=".Length)
    } else {
      break
    }
    $i++
  }
  $remaining = @()
  if ($i -lt $TalkArgs.Count) { $remaining = $TalkArgs[$i..($TalkArgs.Count - 1)] }
  if ($remaining.Count -lt 1) { Exit-WithError "usage: ael talk [--runtime RUNTIME] <role> [prompt...]" }
  $role = $remaining[0]
  $requestParts = @()
  if ($remaining.Count -gt 1) { $requestParts = $remaining[1..($remaining.Count - 1)] }
  if (-not $runtime) { $runtime = Runtime-FromManifest }
  if (-not $runtime) { $runtime = Detect-Runtime }
  if ($requestParts.Count -eq 0) {
    $bin = Get-RuntimeBinary $runtime
    if (-not (Get-CommandNameOrDefault $bin)) { Exit-WithError "$bin CLI not found on PATH" }
    return (Invoke-SubstrateInteractive @("agent", "talk", "--runtime", $runtime, $role))
  }
  return (Invoke-HeadlessTalk $runtime $role ($requestParts -join " "))
}

function Show-TeamMembers {
  $text = @"
Core team:

  pi / 项目经理         派单、跟进、汇总
  advisor / 顾问        反思、识别策略、框架
  writer / 写手         起草段落、引言、改稿
  ra-stata / 实证 RA    回归、表格、Stata 代码
  ra-python / 数据 RA   清洗、合并、Python 代码
  theorist / 理论       识别假设、模型设计
  referee / 内审        内部自审、catch 错误
  replicator / 复现     clean-room 复跑
  pm / 项目管理         Gantt、deadline、acceptance

Tip: PI can summon experts (dof, rr-strategist, writer, econometrician,
viz, lit-reviewer, etc.) - just ask PI.
"@
  Write-AelOut $text
}

function Maybe-PrintFirstWelcome {
  if ($env:AEL_NO_ONBOARDING -eq "1") { return }
  $markerDir = Join-Path (Get-Location) ".aiplus\agents"
  $marker = Join-Path $markerDir ".ael-greeted"
  if (-not (Test-Path $marker)) {
    Write-AelOut "Welcome to AEL - your research team is ready."
    Write-AelOut ""
    New-Item -ItemType Directory -Force -Path $markerDir | Out-Null
    New-Item -ItemType File -Force -Path $marker | Out-Null
  }
}

function Detect-RoleFromInput([string]$Raw) {
  $lower = $Raw.ToLowerInvariant()
  if ($lower -in @("pi", "advisor", "writer", "ra-stata", "ra-python", "theorist", "referee", "replicator", "pm")) {
    return $lower
  }
  if ($lower -match "advisor|顾问|反思|识别|框架|战略|咨询|\brd\b|reflect|reflection") { return "advisor" }
  if ($lower -match "ra-stata|ra_stata|ra stata|stata|回归|实证.*ra|跑表|跑回归") { return "ra-stata" }
  if ($lower -match "ra-python|ra_python|ra python|python.*ra|数据清洗|清洗|合并.*数据|python") { return "ra-python" }
  if ($lower -match "replicator|复现|复跑|clean.room|replication") { return "replicator" }
  if ($lower -match "referee|内审|自审|审稿") { return "referee" }
  if ($lower -match "theorist|理论|模型|识别假设|推导") { return "theorist" }
  if ($lower -match "writer|写手|起草|写段落|draft|引言|introduction|写作") { return "writer" }
  if ($lower -match "pm|项目经理|gantt|deadline|项目管理|acceptance") { return "pm" }
  if ($lower -match "pi|项目经理|派单|下达|执行|orchestrat|coordinator") { return "pi" }
  return ""
}

function Invoke-ChatDefault {
  if (-not (Test-Path (Join-Path (Get-Location) ".aiplus\manifest.json"))) {
    $message = @"
ael: this project is not set up yet.

Run this once to install the research team:
  ael install

Then run "ael" to chat with your team in plain language.
"@
    [Console]::Error.WriteLine($message)
    exit 1
  }

  Maybe-PrintFirstWelcome
  Write-AelOut "AEL - 你想跟谁聊？ / who do you want to talk to?"
  Write-AelOut ""
  Show-TeamMembers
  Write-AelOut ""
  Write-AelOut "Type a name, slug, or describe what you need (中英文皆可)."
  Write-AelOut '"q" / Ctrl-D to leave. Empty = PI.'
  Write-AelOut ""
  Write-AelRaw "> "

  $userInput = $null
  if ($script:AelPipelineInput -and $script:AelPipelineInput.Count -gt 0) {
    $userInput = [string]$script:AelPipelineInput[0]
  } else {
    $userInput = [Console]::In.ReadLine()
  }
  $trimmed = if ($null -eq $userInput) { "" } else { ($userInput -replace "\s+", "").ToLowerInvariant() }
  if ($trimmed -in @("q", "quit", "exit", "bye")) { exit 0 }

  if (-not $trimmed) {
    $role = "pi"
    Write-AelOut "-> pi (default)"
    Write-AelOut ""
  } else {
    $role = Detect-RoleFromInput $userInput
    if (-not $role) {
      [Console]::Error.WriteLine("ael: could not match `"$userInput`" to a team member. Defaulting to PI.")
      $role = "pi"
    } else {
      Write-AelOut "-> $role"
      Write-AelOut ""
    }
  }
  if ($env:AEL_LOBBY_ROUTE_ONLY -eq "1") { return 0 }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath talk $role
  return $LASTEXITCODE
}

function Invoke-Main([string[]]$Argv) {
  $cmd = if ($Argv.Count -gt 0) { $Argv[0] } else { "" }
  $rest = @()
  if ($Argv.Count -gt 1) { $rest = $Argv[1..($Argv.Count - 1)] }
  switch ($cmd) {
    "" { return (Invoke-ChatDefault) }
    "chat" { return (Invoke-ChatDefault) }
    { $_ -in @("pi", "advisor", "writer", "ra-stata", "ra-python", "theorist", "referee", "replicator", "pm") } {
      return (Invoke-Talk @($cmd))
    }
    "-h" { Show-Usage; return 0 }
    "--help" { Show-Usage; return 0 }
    "help" { Show-Usage; return 0 }
    "-V" { Write-AelOut "AEL $script:AelVersion"; return 0 }
    "--version" { Write-AelOut "AEL $script:AelVersion"; return 0 }
    "version" { Write-AelOut "AEL $script:AelVersion"; return 0 }
    "install" { return (Invoke-Install $rest) }
    "talk" { return (Invoke-Talk $rest) }
    "status" { return (Invoke-SubstrateVisible (@("agent", "status") + $rest)) }
    "doctor" { return (Invoke-SubstrateVisible (@("doctor") + $rest)) }
    "update" { return (Invoke-Update $rest) }
    "uninstall" { return (Invoke-Uninstall $rest) }
    "route" { return (Invoke-SubstrateVisible (@("agent", "route") + $rest)) }
    "telemetry" { return (Invoke-Telemetry $rest) }
    "invite" { return (Invoke-SubstrateVisible (@("agent", "invite") + $rest)) }
    "dismiss" { return (Invoke-SubstrateVisible (@("agent", "dismiss") + $rest)) }
    "integrate" { return (Invoke-SubstrateVisible (@("agent", "integrate") + $rest)) }
    "substrate" { return (Invoke-SubstrateVisible $rest) }
    default { Exit-WithError "unknown command: $cmd" }
  }
}

$script:AelPipelineInput = @($input)
$status = 0
$output = Invoke-Main @($args)
foreach ($item in @($output)) {
  if ($item -is [int]) {
    $status = [int]$item
  } elseif ($null -ne $item) {
    Write-Output $item
  }
}
exit $status
