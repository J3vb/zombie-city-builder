param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [switch]$Tests
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') { throw 'Expected a three-part release version.' }
$project = Split-Path $PSScriptRoot -Parent
$csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$out = (New-Item -ItemType Directory -Force -Path $OutputDirectory).FullName
$stamp = Join-Path $out 'LauncherVersion.cs'
@"
using System.Reflection;
[assembly: AssemblyTitle("Hold the Gates Launcher")]
[assembly: AssemblyProduct("Hold the Gates")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyInformationalVersion("$Version")]
"@ | Set-Content -LiteralPath $stamp -Encoding UTF8
$sources = @(Get-ChildItem -LiteralPath (Join-Path $project 'launcher') -Filter '*.cs' | ForEach-Object FullName)
$flags = @('/nologo','/optimize+','/warnaserror+','/platform:x64','/reference:System.Runtime.Serialization.dll','/reference:System.IO.Compression.dll','/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:Microsoft.CSharp.dll')
& $csc @flags /target:winexe "/out:$out/HoldTheGatesLauncher.exe" $stamp @sources
if ($LASTEXITCODE -ne 0) { throw 'Launcher compilation failed.' }
if ($Tests) {
    $test = Join-Path $project 'launcher/tests/LauncherTests.cs'
    & $csc @flags /target:exe /main:HoldTheGates.LauncherTests "/out:$out/LauncherTests.exe" $stamp @sources $test
    if ($LASTEXITCODE -ne 0) { throw 'Launcher test compilation failed.' }
    & "$out/LauncherTests.exe"
    if ($LASTEXITCODE -ne 0) { throw 'Launcher update tests failed.' }
}

