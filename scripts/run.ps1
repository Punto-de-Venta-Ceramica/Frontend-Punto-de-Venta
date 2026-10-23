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
    if ($LASTEXITCODE -ne 0) { throw "Flutter terminó con código $LASTEXITCODE" }
} finally {
    Pop-Location
}
