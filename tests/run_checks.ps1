param([string]$Lazarus = 'C:\lazarus', [string]$Target = 'x86_64-win64')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'build\professor'
$baseline = Join-Path $projectRoot '.deps\chatgpt-integration-baseline'
$buildOptions = @{Lazarus=$Lazarus;Platform=$Target}
if (Test-Path $baseline) { $buildOptions.ChatGPT=$baseline }
foreach ($check in @('vision_check', 'reception_tests', 'app_checks')) {
    & (Join-Path $projectRoot 'scripts\build_professor.ps1') @buildOptions -Target ('tests\'+$check+'.lpr')
    $previousConfig = $env:ASSISTENTE_CONFIG_DIR
    try {
        $env:ASSISTENTE_CONFIG_DIR = Join-Path $outputDir ($check + '-config')
        & (Join-Path $outputDir ($check + '.exe'))
    } finally { $env:ASSISTENTE_CONFIG_DIR = $previousConfig }
    if ($LASTEXITCODE -ne 0) { throw "Check failed: $check" }
    Write-Output "PASS $check"
}
Write-Output "Validation outputs: $outputDir"
