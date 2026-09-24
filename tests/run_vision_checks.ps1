param([switch]$Hardware, [string]$Lazarus = 'C:\lazarus')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$libraryRoot = Join-Path (Split-Path $projectRoot -Parent) 'CHATGPT\pacote'
$outputDir = Join-Path ([IO.Path]::GetTempPath()) ('assistente-vision-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $outputDir | Out-Null
$compilerArgs = @('-MObjFPC','-Scghi','-dLCL','-dLCLwin32', ('-Fu' + $projectRoot + '\src'), ('-Fu' + $projectRoot + '\vendor\chatgpt-voice'), ('-FU' + $outputDir), ('-FE' + $outputDir))
foreach ($relative in @('lcl\units\i386-win32\win32','lcl\units\i386-win32','components\lazutils\lib\i386-win32','packager\units\i386-win32')) {
    $compilerArgs += '-Fu' + (Join-Path $Lazarus $relative)
}
$dirs = Get-ChildItem -LiteralPath $libraryRoot -Directory -Recurse |
    Where-Object { $_.FullName -notmatch '\\samples\\|\\samples$|\\lib\\' }
foreach ($d in $dirs) {
    $compilerArgs += '-Fu' + $d.FullName
    $compilerArgs += '-Fi' + $d.FullName
}
$checks = @('vision_check')
if ($Hardware) { $checks += 'webcam_check' }
foreach ($check in $checks) {
    & (Join-Path $Lazarus 'fpc\3.2.2\bin\i386-win32\fpc.exe') @compilerArgs (Join-Path $PSScriptRoot ($check + '.lpr'))
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $check" }
    & (Join-Path $outputDir ($check + '.exe'))
    if ($LASTEXITCODE -ne 0) { throw "Check failed: $check" }
}
Write-Output "Validation outputs: $outputDir"
