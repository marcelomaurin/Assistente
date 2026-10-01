param([string]$Lazarus = 'C:\lazarus', [string]$Target = 'x86_64-win64')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$libraryRoot = Join-Path (Split-Path $projectRoot -Parent) 'CHATGPT\pacote'
$outputDir = Join-Path $projectRoot ('tests\test-output\' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$compiler = Join-Path $Lazarus ('fpc\3.2.2\bin\' + $Target + '\fpc.exe')
$compilerArgs = @('-MObjFPC','-Scghi','-dLCL','-dLCLwin32',
    ('-Fu' + $projectRoot + '\src'), ('-Fu' + $projectRoot + '\vendor\chatgpt-voice'),
    ('-FU' + $outputDir), ('-FE' + $outputDir))
foreach ($relative in @("lcl\units\$Target\win32", "lcl\units\$Target",
    "components\lazutils\lib\$Target", "packager\units\$Target",
    "components\synedit\units\$Target\win32", "components\lazcontrols\lib\$Target\win32")) {
    $compilerArgs += '-Fu' + (Join-Path $Lazarus $relative)
}
foreach ($d in (Get-ChildItem -LiteralPath $libraryRoot -Directory -Recurse |
    Where-Object { $_.FullName -notmatch '\\samples\\|\\samples$|\\lib\\' })) {
    $compilerArgs += '-Fu' + $d.FullName
    $compilerArgs += '-Fi' + $d.FullName
}
foreach ($check in @('vision_check', 'reception_tests', 'app_checks')) {
    $log = Join-Path $outputDir ($check + '-build.log')
    & $compiler @compilerArgs (Join-Path $PSScriptRoot ($check + '.lpr')) *> $log
    if ($LASTEXITCODE -ne 0) { Get-Content $log -Tail 20; throw "Compilation failed: $check" }
    $previousConfig = $env:ASSISTENTE_CONFIG_DIR
    try {
        $env:ASSISTENTE_CONFIG_DIR = Join-Path $outputDir ($check + '-config')
        & (Join-Path $outputDir ($check + '.exe'))
    } finally { $env:ASSISTENTE_CONFIG_DIR = $previousConfig }
    if ($LASTEXITCODE -ne 0) { throw "Check failed: $check" }
    Write-Output "PASS $check"
}
Write-Output "Validation outputs: $outputDir"
