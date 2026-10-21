param(
    [string]$Lazarus = 'C:\lazarus',
    [string]$ChatGPT = (Join-Path $PSScriptRoot '..\..\CHATGPT'),
    [string]$Castle = $env:CASTLE_ENGINE_PATH,
    [ValidateSet('i386-win32','x86_64-win64')][string]$Platform = 'i386-win32',
    [string]$Compiler = '',
    [string]$Target = 'src\assistente.lpr',
    [switch]$Run,
    [string[]]$RunArguments = @(),
    [switch]$Rebuild,
    [switch]$Release
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $Castle) { $Castle = Join-Path $root '.deps\castle-engine' }
$Castle = (Resolve-Path -LiteralPath $Castle).Path
$ChatGPT = (Resolve-Path -LiteralPath $ChatGPT).Path
$out = Join-Path $root 'build\professor'
$units = Join-Path $out ('units\' + $Platform)
New-Item -ItemType Directory -Force -Path $units | Out-Null
if (-not $Compiler) {
    $Compiler = Join-Path $Lazarus ('fpc\3.2.2\bin\' + $Platform + '\fpc.exe')
    if (-not (Test-Path -LiteralPath $Compiler)) { $Compiler = 'C:\FPC\3.2.2\bin\' + $Platform + '\fpc.exe' }
}
if (-not (Test-Path -LiteralPath $Compiler)) { throw "Compilador ausente: $Compiler" }
$argsList = @('-MObjFPC','-Scghi','-O1','-gl','-dLCL','-dLCLwin32','-dCASTLE_ENGINE_LAZARUS_PACKAGE',
    ('-FU' + $units), ('-FE' + $out), ('-Fu' + $root + '\src'),
    ('-Fu' + $root + '\vendor\chatgpt-voice'))
if ($Rebuild) { $argsList += '-B' }
if ($Release) { $argsList = @($argsList | Where-Object { $_ -ne '-gl' }); $argsList += '-Xs' }
if ($Target -match '(assistente|professor_ui_smoke)\.lpr$') { $argsList += '-WG' }
foreach ($rel in @("lcl\units\$Platform\win32", "lcl\units\$Platform",
    "components\lazutils\lib\$Platform", "packager\units\$Platform",
    'components\opengl', "components\synedit\units\$Platform\win32",
    "components\lazcontrols\lib\$Platform\win32",
    "components\ideintf\units\$Platform\win32",
    "components\buildintf\units\$Platform")) { $argsList += '-Fu' + (Join-Path $Lazarus $rel) }
# Use the same source/include paths as the official CGE Lazarus packages.
foreach ($package in @('castle_engine_base','castle_engine_lcl')) {
    $path = Join-Path $Castle ('packages\lazarus\' + $package + '.lpk')
    [xml]$xml = Get-Content -LiteralPath $path
    foreach ($entry in $xml.CONFIG.Package.CompilerOptions.SearchPaths.OtherUnitFiles.Value.Split(';')) {
        $argsList += '-Fu' + [IO.Path]::GetFullPath((Join-Path (Split-Path $path) $entry))
    }
    foreach ($entry in $xml.CONFIG.Package.CompilerOptions.SearchPaths.IncludeFiles.Value.Split(';')) {
        $argsList += '-Fi' + [IO.Path]::GetFullPath((Join-Path (Split-Path $path) $entry))
    }
}
$argsList += '-Fu' + $ChatGPT
foreach ($dir in Get-ChildItem -LiteralPath (Join-Path $ChatGPT 'pacote') -Recurse -Directory |
    Where-Object { $_.FullName -notmatch '\\samples(\\|$)|\\lib(\\|$)|\\backup(\\|$)' }) {
    $argsList += '-Fu' + $dir.FullName
    $argsList += '-Fi' + $dir.FullName
}
Push-Location $root
try {
    $buildLog = Join-Path $out ([IO.Path]::GetFileNameWithoutExtension($Target) + '-build.log')
    & $Compiler @argsList (Join-Path $root $Target) 2>&1 | Tee-Object -FilePath $buildLog
    if ($LASTEXITCODE -ne 0) { throw "Compilação falhou ($LASTEXITCODE). Consulte $buildLog" }
    Copy-Item -LiteralPath (Join-Path $root 'AVATARES') -Destination $out -Recurse -Force
    $exe = Join-Path $out ([IO.Path]::GetFileNameWithoutExtension($Target) + '.exe')
    if ($Run) {
        & $exe @RunArguments
        if ($LASTEXITCODE -ne 0) { throw "Execução falhou: $LASTEXITCODE" }
    }
    Write-Output "Executável: $exe"
} finally { Pop-Location }
