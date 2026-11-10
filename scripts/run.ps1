param(
    [ValidateSet('chrome', 'edge', 'android', 'windows')]
    [string]$Target = 'chrome',
    [string]$ApiBaseUrl = ''
)
$ErrorActionPreference = 'Stop'
$frontendRoot = Split-Path -Parent $PSScriptRoot
$localFlutter = Join-Path (Split-Path -Parent $frontendRoot) '.tools\flutter\bin\flutter.bat'
if (Test-Path -LiteralPath $localFlutter) {
    $flutterCommand = $localFlutter
} else {
    $flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
}

# Native-asset hooks can invoke Dart without quoting its SDK path on Windows.
# Use the existing Windows short path without moving or changing the SDK.
if ($env:OS -eq 'Windows_NT' -and $flutterCommand -match '\s') {
    $previousFlutterExecutable = $env:BARROCONTROL_FLUTTER_EXECUTABLE
    try {
        $env:BARROCONTROL_FLUTTER_EXECUTABLE = $flutterCommand
        $flutterShortPath = & $env:ComSpec /d /v:off /c 'for %I in ("%BARROCONTROL_FLUTTER_EXECUTABLE%") do @echo "%~sI"'
        $shortPathExitCode = $LASTEXITCODE
    } finally {
        $env:BARROCONTROL_FLUTTER_EXECUTABLE = $previousFlutterExecutable
    }
    $flutterShortPath = ([string]$flutterShortPath).Trim().Trim('"')
    if ($shortPathExitCode -ne 0 -or
        [string]::IsNullOrWhiteSpace($flutterShortPath) -or
        $flutterShortPath -match '\s') {
        throw 'No se pudo obtener una ruta corta para Flutter. Instala el SDK en una carpeta sin espacios.'
    }
    $flutterCommand = $flutterShortPath
}

Push-Location $frontendRoot
try {
    $runArguments = @('run')
    if ($Target -eq 'android') {
        # Flutter asks which Android device to use when more than one is present.
        if (-not $ApiBaseUrl) { $ApiBaseUrl = 'http://10.0.2.2:8080' }
    } else {
        $runArguments += @('-d', $Target)
    }
    if ($Target -in @('chrome', 'edge')) { $runArguments += '--web-port=5173' }
    if ($ApiBaseUrl) { $runArguments += "--dart-define=API_BASE_URL=$ApiBaseUrl" }
    & $flutterCommand @runArguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter termino con codigo $LASTEXITCODE" }
} finally {
    Pop-Location
}
