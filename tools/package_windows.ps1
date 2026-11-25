param(
    [Parameter(Mandatory)][string]$ToolCache,
    [string]$Version = "local",
    [switch]$Render
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^[a-zA-Z0-9._-]+$') { throw "Invalid build version" }
$project = $PSScriptRoot | Split-Path -Parent
$cache = (Resolve-Path -LiteralPath $ToolCache).Path
$editor = Join-Path $cache '4.5.1-stable/Godot_v4.5.1-stable_win64_console.exe'
$out = Join-Path $project "build/windows/$Version"
$null = New-Item -ItemType Directory -Force -Path $out
$game = Join-Path $out 'HoldTheGates.exe'
& python (Join-Path $project 'tools/build_flow.py')
if ($LASTEXITCODE -ne 0) { throw "Native pathfinding build failed" }
$oldAppData = $env:APPDATA
$oldLocalData = $env:LOCALAPPDATA

function Test-EngineLog([string]$Log) {
    if (!(Test-Path -LiteralPath $Log)) { throw "Godot did not write $Log" }
    if (Select-String -LiteralPath $Log -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' -Quiet) {
        Get-Content -LiteralPath $Log
        throw "Godot reported an error in $Log"
    }
}

try {
    $env:APPDATA = $cache
    $env:LOCALAPPDATA = Join-Path $cache 'Local'
    $null = New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA
    $importLog = Join-Path $out 'import.log'
    & $editor --headless --path $project --log-file $importLog --import
    if ($LASTEXITCODE -ne 0) { throw "Import failed" }
    Test-EngineLog $importLog
    $exportLog = Join-Path $out 'export.log'
    & $editor --headless --path $project --log-file $exportLog --export-release 'Windows Desktop' $game
    if ($LASTEXITCODE -ne 0) { throw "Windows export failed" }
    Test-EngineLog $exportLog
    if (!(Test-Path -LiteralPath $game)) { throw "Missing packaged executable" }

    Copy-Item -LiteralPath (Join-Path $project 'native_bin/godot-cpp-LICENSE.txt') -Destination $out
    $bench = Join-Path $project 'tests/bench_flow_field.gd'
    $flowLog = Join-Path $out 'smoke-flow.log'
    $argsFlow = @('--headless','--log-file',('"' + $flowLog + '"'),'--script',('"' + $bench + '"'),'--','require-native')
    $flow = Start-Process -FilePath $game -WorkingDirectory $out -ArgumentList $argsFlow -WindowStyle Hidden -PassThru
    if (!$flow.WaitForExit(30000)) { $flow.Kill(); throw "Packaged flow test timed out" }
    if ($flow.ExitCode -ne 0) { throw "Packaged flow test failed" }
    Test-EngineLog $flowLog
    if (!(Select-String -LiteralPath $flowLog -Pattern 'ms per build' -Quiet)) { throw "No flow timing from package" }

    # Launch away from the checkout so all assets must come from the embedded game.
    foreach ($scene in @('default','settlement')) {
        $smokeLog = Join-Path $out "smoke-$scene.log"
        $opts = @('--quit-after','150','--log-file',('"' + $smokeLog + '"'))
        if ($Render) { $opts += @('--resolution','1920x1080','--disable-vsync') }
        else { $opts += '--headless' }
        if ($scene -eq 'settlement') { $opts += 'res://scenes/main/main.tscn' }
        $proc = Start-Process -FilePath $game -WorkingDirectory $out -ArgumentList $opts -WindowStyle Hidden -PassThru
        if (!$proc.WaitForExit(90000)) { $proc.Kill(); throw "Packaged game timed out" }
        if ($proc.ExitCode -ne 0) { throw "Packaged game exited with $($proc.ExitCode)" }
        Test-EngineLog $smokeLog
        if ($Render) {
            if (!(Select-String -LiteralPath $smokeLog -Pattern 'Using Device' -Quiet)) {
                throw "Rendered smoke test did not initialize a GPU"
            }
            Select-String -LiteralPath $smokeLog -Pattern 'Using Device'
        }
    }
    Write-Output "Verified $game"
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalData
}
