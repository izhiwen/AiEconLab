$ErrorActionPreference = "Stop"

$script:AelVersion = if ($env:AEL_VERSION) { $env:AEL_VERSION.TrimStart("v") } else { "0.3.0" }
$script:AelRepo = if ($env:AEL_REPO) { $env:AEL_REPO } else { "izhiwen/AiEconLab" }
$script:MinimumSupported = if ($env:AEL_MINIMUM_SUPPORTED_VERSION) { $env:AEL_MINIMUM_SUPPORTED_VERSION } else { "v0.3.0" }
$script:BinDir = Split-Path -Parent $PSCommandPath
$script:AelRoot = $script:BinDir
if (Test-Path (Join-Path (Split-Path -Parent $script:BinDir) "libexec")) {
  $script:AelRoot = Split-Path -Parent $script:BinDir
}
if ([string]::IsNullOrEmpty($env:AIPLUS_BRAND)) { $env:AIPLUS_BRAND = "AEL" }
if ([string]::IsNullOrEmpty($env:AIPLUS_TEAM)) { $env:AIPLUS_TEAM = "aieconlab" }
if ([string]::IsNullOrEmpty($env:AIPLUS_DEFAULT_ROLE)) { $env:AIPLUS_DEFAULT_ROLE = "pi" }

function Write-AelError([string]$Message) {
  [Console]::Error.WriteLine("ael: $Message")
}

function Write-AelOut([string]$Text = "") {
  Write-Output $Text
}

function Exit-WithError([string]$Message, [int]$Code = 1) {
  Write-AelError $Message
  exit $Code
}

function Show-Usage {
  $text = @"
AEL $script:AelVersion

Usage:
  ael install [codex|claude-code|opencode|all]   set up the research team here (once per project)
  ael update [--dry-run]                          update the installed ael CLI
  ael uninstall [--purge] [--yes]                 remove the installed ael CLI
  ael                                             open the lobby - pick or describe who you want to talk to
  ael <role>                                      shortcut: resume the last chat with that role
  ael status                                      show installed team + active runtime
  ael refresh [--dry-run]                         refresh managed project assets
  ael doctor [--fix] [--yes]                      self-check and fix common drift

Roles you can chat with directly:
  ael pi                                          PI - triage, dispatch, synthesize
  ael advisor                                     Advisor - reflect, strategy, framing
  ael writer                                      Writer - draft and revise prose
  ael ra-stata                                    Empirical RA - regressions, tables, Stata
  ael ra-python                                   Data RA - cleaning, merging, Python
  ael theorist                                    Theory - assumptions and models
  ael referee                                     Internal referee - critical review
  ael replicator                                  Replicator - clean-room rerun
  ael pm                                          Project management - timeline, deadlines

Advanced (you rarely need these once you are in chat):
  ael talk [--runtime RUNTIME] <role> [prompt...]
  ael talk --resume <role> [--last|--list]
  ael route <role> <task...>
  ael update [--dry-run]
  ael uninstall [--purge] [--yes]
  ael --version

Environment variables:
  AEL_AIPLUS_BIN=/path/to/ael-support             use a specific bundled runtime

Recommended flow:
  ael install                       # Windows: set up the team once per project
  ael                               # then open the lobby - pick who you want
                                    # type/say who you want (PI, Advisor, ...)
                                    # or "reflect on my RD design" and it routes you to Advisor

Two-window pattern (for serious paper work):
  Window 1: ael advisor             # consult on framing / identification
  Window 2: ael pi                  # issue execution instructions

Examples:
  ael install
  ael update --dry-run                # preview an available CLI update
  ael uninstall --yes                 # remove the installed CLI, keep project files
  ael                               # opens the lobby
  ael pi                            # resume PI for this project
  ael advisor                       # resume Advisor for this project
  ael advisor --fresh               # open a new Advisor session
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
  if ($versionOut -match "^AEL\s+(v?[0-9]+(?:\.[0-9]+){1,2})") {
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
      Get-Content -LiteralPath $tmp | ForEach-Object { [Console]::Error.WriteLine($_) }
    }
    return $status
  } finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-SubstrateVisible([string[]]$SubArgs) {
  $bin = Get-SubstrateBin
  & $bin @SubArgs
  return $LASTEXITCODE
}

function Invoke-SubstrateInteractive([string[]]$SubArgs) {
  $bin = Get-SubstrateBin
  if ($SubArgs.Count -gt 0) {
    & $bin @SubArgs
  } else {
    & $bin
  }
  return $LASTEXITCODE
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

function Test-ProjectHasAelPersonas {
  $personaDir = Join-Path (Get-Location) ".aiplus\agents\personas"
  foreach ($role in @("pi", "advisor", "writer", "ra-stata", "ra-python", "theorist", "referee", "replicator", "pm")) {
    if (-not (Test-Path (Join-Path $personaDir "$role.md"))) { return $false }
  }
  return $true
}

function Test-ProjectReadyForLobby {
  $manifest = Join-Path (Get-Location) ".aiplus\manifest.json"
  return ((Test-Path $manifest) -and (Test-ProjectHasAelPersonas))
}

function Get-AvailableRuntimes {
  $runtimes = @()
  if (Get-CommandNameOrDefault "codex") { $runtimes += "codex" }
  if (Get-CommandNameOrDefault "claude") { $runtimes += "claude-code" }
  if (Get-CommandNameOrDefault "opencode") { $runtimes += "opencode" }
  return $runtimes
}

function Write-NoRuntimeFound {
  [Console]::Error.WriteLine(@"
ael: no runtime found on PATH.

Install at least one supported AI coding runtime, then run "ael" again:
  Claude Code: https://claude.com/download
  Codex:       https://developers.openai.com/codex
  OpenCode:    https://opencode.ai
"@)
}

function Write-InstallProgressStart([string]$Label, [bool]$ShowProgress) {
  if ($ShowProgress) { [Console]::Out.WriteLine("ael:   $Label...") }
}

function Write-InstallProgressDone([string]$Label, [bool]$ShowProgress) {
  if ($ShowProgress) {
    $check = [char]0x2713
    [Console]::Out.WriteLine("ael:   $check $Label")
  }
}

function Ensure-ProjectReadyForLobby {
  $script:AelEnsureProjectReadyStatus = 0
  if (Test-ProjectReadyForLobby) { return }

  $availableRuntimes = @(Get-AvailableRuntimes)
  if ($availableRuntimes.Count -eq 0) {
    Write-NoRuntimeFound
    $script:AelEnsureProjectReadyStatus = 1
    return
  }

  [Console]::Out.WriteLine("ael: first time in this project - setting up the AEL research team...")
  $installed = @()
  foreach ($runtime in $availableRuntimes) {
    $result = Invoke-InstallRuntimeFlow -Runtime $runtime -PassArgs @() -ShowProgress $true
    if (-not $result.Success) {
      [Console]::Error.WriteLine("ael: auto-install failed for $runtime at $($result.Step): $($result.Reason)")
      $script:AelEnsureProjectReadyStatus = 1
      return
    }
    $installed += $runtime
  }

  [Console]::Out.WriteLine("AEL set up for: $($installed -join ', ')")
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
    $dryRunRuntimes = if ($runtime -eq "all") { @("codex", "claude-code", "opencode") } else { @($runtime) }
    foreach ($dryRunRuntime in $dryRunRuntimes) {
      Write-AelOut "  runtime=$dryRunRuntime"
      Write-AelOut "    would bootstrap the project runtime adapter"
      Write-AelOut "    would install the AiEconLab research team"
      Write-AelOut "    would set AiEconLab as the active team"
      Write-AelOut "    would register the MCP server with $dryRunRuntime (native tool-use for chat)"
    }
    Write-AelOut "AEL_DRY_RUN=PASS"
    return 0
  }
  if ($runtime -eq "all") {
    $failures = 0
    $summary = @()
    foreach ($installRuntime in @("codex", "claude-code", "opencode")) {
      $result = Invoke-InstallRuntimeFlow -Runtime $installRuntime -PassArgs $passArgs
      if ($result.Success) {
        Write-AelOut "AEL install runtime=$installRuntime status=PASS"
        $summary += "$installRuntime PASS"
      } else {
        $failures++
        [Console]::Error.WriteLine("AEL install runtime=$installRuntime status=FAIL step=$($result.Step) reason=$($result.Reason)")
        $summary += "$installRuntime FAIL ($($result.Reason))"
      }
    }
    Write-AelOut "AEL installed: $($summary -join ', ')"
    if ($failures -eq 0) {
      Write-AelOut "Next: ael                  # chat with your team in plain English / Chinese"
      Show-OnboardingHint
      return 0
    }
    return 1
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

function Get-InstallFailureReason([int]$Status) {
  if ($Status -eq 0) { return "" }
  return "exit_code=$Status"
}

function Invoke-InstallRuntimeFlow([string]$Runtime, [string[]]$PassArgs, [bool]$ShowProgress = $false) {
  $label = "installing runtime adapter ($Runtime)"
  Write-InstallProgressStart $label $ShowProgress
  $status = Invoke-SubstrateQuiet (@("install", $Runtime, "--allow-version-skew") + $PassArgs)
  if ($status -ne 0) {
    return [pscustomobject]@{ Success = $false; Step = "install"; Reason = (Get-InstallFailureReason $status) }
  }
  Write-InstallProgressDone $label $ShowProgress

  $label = "adding aieconlab team"
  Write-InstallProgressStart $label $ShowProgress
  $status = Invoke-SubstrateQuiet @("add", "aieconlab")
  if ($status -ne 0) {
    return [pscustomobject]@{ Success = $false; Step = "add"; Reason = (Get-InstallFailureReason $status) }
  }
  Write-InstallProgressDone $label $ShowProgress

  $label = "setting active team"
  Write-InstallProgressStart $label $ShowProgress
  $status = Invoke-SubstrateQuiet @("agent", "set-team", "aieconlab")
  if ($status -ne 0) {
    return [pscustomobject]@{ Success = $false; Step = "set-team"; Reason = (Get-InstallFailureReason $status) }
  }
  Write-InstallProgressDone $label $ShowProgress

  $label = "registering MCP server"
  Write-InstallProgressStart $label $ShowProgress
  $status = Invoke-SubstrateQuiet @("mcp-register", "--runtime", $Runtime)
  if ($status -ne 0) {
    return [pscustomobject]@{ Success = $false; Step = "mcp-register"; Reason = (Get-InstallFailureReason $status) }
  }
  Write-InstallProgressDone $label $ShowProgress
  return [pscustomobject]@{ Success = $true; Step = ""; Reason = "" }
}

function Invoke-Talk([string[]]$TalkArgs) {
  return (Invoke-SubstrateInteractive (@("agent", "talk") + $TalkArgs))
}

function Get-RoleTalkArgs([string]$Role, [string[]]$Rest) {
  $fresh = $false
  $filtered = @()
  foreach ($part in $Rest) {
    if ($part -eq "--fresh") {
      $fresh = $true
    } else {
      $filtered += $part
    }
  }
  $talkArgs = @("agent", "talk")
  if (-not $fresh) { $talkArgs += "--resume" }
  $talkArgs += $Role
  $talkArgs += $filtered
  return $talkArgs
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

function Invoke-ChatDefault {
  Ensure-ProjectReadyForLobby
  if ($script:AelEnsureProjectReadyStatus -ne 0) { return $script:AelEnsureProjectReadyStatus }

  Maybe-PrintFirstWelcome
  return (Invoke-SubstrateInteractive @())
}

function Test-AieconlabProject {
  $root = Get-Location
  if (Test-Path (Join-Path $root ".aiplus\modules\aieconlab")) { return $true }
  $manifest = Join-Path $root ".aiplus\manifest.json"
  if ((Test-Path $manifest) -and ((Get-Content -LiteralPath $manifest -Raw) -match '"aieconlab"')) {
    return $true
  }
  $team = Join-Path $root ".aiplus\team.toml"
  if ((Test-Path $team) -and ((Get-Content -LiteralPath $team -Raw) -match '(?m)^\s*(active_team|team)\s*=\s*"?aieconlab"?')) {
    return $true
  }
  return $false
}

function Test-AelConsultantTeam {
  if (-not (Test-AieconlabProject)) { return 0 }
  $consultant = Join-Path (Get-Location) ".aiplus\consultant-team.toml"
  if (-not (Test-Path $consultant)) { return 0 }

  $text = Get-Content -LiteralPath $consultant -Raw
  $missing = $false
  foreach ($needle in @(
    'id = "design"',
    'id = "contribution"',
    'id = "reproducibility"',
    'id = "irb"',
    'id = "ai_integration"',
    'id = "top_tier_referee"',
    'id = "jmp_audience"',
    'id = "external_replicator"',
    'id = "submission"',
    'id = "working-paper-post"',
    'id = "referee-response-send"',
    'id = "data-share"',
    'id = "authorship-change"'
  )) {
    if (-not $text.Contains($needle)) { $missing = $true }
  }
  if ($text -notmatch 'light[.]review_mode\s*=\s*"skip"') { $missing = $true }
  if ($text -match 'id = "(product_market|ux_plain_english|trust_safety|implementation_qa|runtime_qa|strategic_critic)"') {
    $missing = $true
  }

  if ($missing) {
    Write-AelOut 'NEEDS_FIX ael_consultant_team_mismatch expected=aieconlab_research_config path=.aiplus/consultant-team.toml fix="ael install"'
    return 1
  }
  Write-AelOut "PASS ael_consultant_team_research_config path=.aiplus/consultant-team.toml"
  return 0
}

function Invoke-Doctor([string[]]$DoctorArgs) {
  $bin = Get-SubstrateBin
  $subArgs = @("doctor") + $DoctorArgs
  & $bin @subArgs
  $status = $LASTEXITCODE
  $consultantStatus = 0
  foreach ($item in @(Test-AelConsultantTeam)) {
    if ($item -is [int]) {
      $consultantStatus = [int]$item
    } elseif ($null -ne $item) {
      Write-AelOut $item
    }
  }
  if ($status -ne 0) { return $status }
  return $consultantStatus
}

function Invoke-Main([string[]]$Argv) {
  $cmd = if ($Argv.Count -gt 0) { $Argv[0] } else { "" }
  $rest = @()
  if ($Argv.Count -gt 1) { $rest = $Argv[1..($Argv.Count - 1)] }
  switch ($cmd) {
    "" { return (Invoke-ChatDefault) }
    "chat" {
      if ($rest.Count -gt 0) {
        Exit-WithError "ael chat does not accept arguments. Use 'ael' for the lobby, or 'ael `"...`"' for natural-language routing."
      }
      return (Invoke-ChatDefault)
    }
    { $_ -in @("pi", "advisor", "writer", "ra-stata", "ra-python", "theorist", "referee", "replicator", "pm") } {
      return (Invoke-SubstrateInteractive (Get-RoleTalkArgs $cmd $rest))
    }
    "-h" { Show-Usage; return 0 }
    "--help" { Show-Usage; return 0 }
    "help" { Show-Usage; return 0 }
    "-V" { Write-AelOut "AEL $script:AelVersion (aiplus 0.6.19+)"; return 0 }
    "--version" { Write-AelOut "AEL $script:AelVersion (aiplus 0.6.19+)"; return 0 }
    "version" { Write-AelOut "AEL $script:AelVersion (aiplus 0.6.19+)"; return 0 }
    "install" { return (Invoke-Install $rest) }
    "talk" { return (Invoke-Talk $rest) }
    "status" { return (Invoke-SubstrateVisible (@("agent", "status") + $rest)) }
    "refresh" { return (Invoke-SubstrateVisible (@("refresh") + $rest)) }
    "doctor" { return (Invoke-Doctor $rest) }
    "update" { return (Invoke-Update $rest) }
    "uninstall" { return (Invoke-Uninstall $rest) }
    "route" { return (Invoke-SubstrateVisible (@("agent", "route") + $rest)) }
    "telemetry" { Exit-WithError "ael telemetry has been removed" }
    "invite" { return (Invoke-SubstrateVisible (@("agent", "invite") + $rest)) }
    "dismiss" { return (Invoke-SubstrateVisible (@("agent", "dismiss") + $rest)) }
    "integrate" { return (Invoke-SubstrateVisible (@("agent", "integrate") + $rest)) }
    "substrate" { return (Invoke-SubstrateVisible $rest) }
    { $Argv.Count -eq 1 -and -not $cmd.StartsWith("-") } {
      return (Invoke-SubstrateInteractive @("agent", "talk", $cmd))
    }
    default {
      if ($Argv.Count -gt 1) {
        Exit-WithError "unknown command or multi-word natural-language input: $($Argv -join ' '). Use 'ael `"...`"' for freeform requests, or 'ael talk ...' for explicit chat."
      }
      Exit-WithError "unknown command: $cmd"
    }
  }
}

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
