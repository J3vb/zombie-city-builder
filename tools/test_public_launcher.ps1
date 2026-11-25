param([Parameter(Mandatory)][string]$PreviousLauncher)
$ErrorActionPreference = 'Stop'
$base = 'https://github.com/J3vb/zombie-city-builder/releases'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('htg-channel-' + [guid]::NewGuid().ToString('N'))
$root = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'HoldTheGates'
if (Test-Path -LiteralPath $root) { throw 'The public install test needs a clean Windows user profile.' }
$null = New-Item -ItemType Directory -Path $temp
$manifest = Invoke-RestMethod "$base/latest/download/windows-update.json" -MaximumRetryCount 3
if ($manifest.schema -ne 1 -or $manifest.version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid public release' }
$download = Join-Path $temp 'HoldTheGatesLauncher.exe'
Invoke-WebRequest "$base/download/v$($manifest.version)/HoldTheGatesLauncher.exe" -OutFile $download -MaximumRetryCount 3
if ((Get-FileHash -LiteralPath $download).Hash -ne $manifest.launcher_sha256) { throw 'Public launcher hash mismatch' }

# Start a real previous-version EXE and follow its process handoff through the Start menu shortcut.
function Start-GameProcess([string]$Path, [string]$Arguments) {
    $info = [Diagnostics.ProcessStartInfo]::new($Path, $Arguments)
    $info.WorkingDirectory = Split-Path $Path -Parent
    $info.UseShellExecute = $false
    return [Diagnostics.Process]::Start($info)
}
$entry = Start-GameProcess (Resolve-Path -LiteralPath $PreviousLauncher).Path ''
$entry.Dispose()
$deadline = [DateTime]::UtcNow.AddMinutes(4)
$game = $null
$runningLauncher = $null
$link = Join-Path ([Environment]::GetFolderPath('Programs')) 'Hold the Gates.lnk'
$shell = New-Object -ComObject WScript.Shell
while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $link) {
        $installed = $shell.CreateShortcut($link).TargetPath
        if (Test-Path -LiteralPath $installed) {
            $activeVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($installed).ProductVersion
            if ($activeVersion -match '^\d+\.\d+\.\d+$' -and [version]$activeVersion -gt [version]$manifest.version) {
                # A newer main build may have published during this run.
                $newer = Invoke-RestMethod "$base/download/v$activeVersion/windows-update.json" -MaximumRetryCount 3
                if ($newer.schema -ne 1 -or $newer.version -ne $activeVersion) { throw 'Invalid newer release' }
                $manifest = $newer
            }
        }
        if ((Test-Path -LiteralPath $installed) -and (Get-FileHash -LiteralPath $installed).Hash -eq $manifest.launcher_sha256) {
            $runningLauncher = Get-Process -Name HoldTheGatesLauncher -ErrorAction SilentlyContinue |
                Where-Object { $_.Path -eq $installed } | Select-Object -First 1
        }
    }
    $receipt = Get-ChildItem -Path "$root/games/*/installed.txt" -ErrorAction SilentlyContinue |
        Where-Object { $lines = @(Get-Content -LiteralPath $_.FullName); $lines[0] -eq $manifest.version -and $lines[1] -eq $manifest.game_sha256 } |
        Select-Object -First 1
    if ($receipt -and $runningLauncher) {
        $game = Join-Path $receipt.DirectoryName 'HoldTheGates.exe'
        break
    }
    Start-Sleep -Seconds 1
}
if (!$game) { throw "The public launcher did not install and activate v$($manifest.version) in time." }
$log = Join-Path $temp 'game.log'
$smoke = Join-Path $PSScriptRoot 'windows_smoke.gd'
$child = Start-GameProcess $game ('--headless --log-file "' + $log + '" --script "' + $smoke + '" -- settlement')
if (!$child.WaitForExit(90000)) { $child.Kill(); throw 'The installed game timed out.' }
if ($child.ExitCode -ne 0 -or !(Test-Path -LiteralPath $log) -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|^ERROR:' -Quiet)) {
    throw 'The publicly installed game failed to start the settlement.'
}
$null = $runningLauncher.CloseMainWindow()
Write-Output "Verified public launcher handoff, Start menu shortcut, game installation and settlement launch for v$($manifest.version)."
