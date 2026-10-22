param([string]$Compiler32='C:\FPC\3.2.2\bin\i386-win32\fpc.exe',
      [string]$Compiler64='C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
foreach ($entry in @(@('win32',$Compiler32),@('win64',$Compiler64))) {
    $out=Join-Path $root ('bin\integration\'+$entry[0])
    $units=Join-Path $root ('build\integration\'+$entry[0])
    New-Item -ItemType Directory -Path $out,$units -Force | Out-Null
    & $entry[1] '-MObjFPC' '-O2' '-Xs' ('-Fu'+$root+'\src') ('-FU'+$units) ('-FE'+$out) (Join-Path $root 'sdk\assistente_integration.lpr')
    if ($LASTEXITCODE -ne 0) { throw ('Falha no build '+$entry[0]) }
    $dll=Join-Path $out 'assistente_integration.dll'
    if (-not (Test-Path -LiteralPath $dll)) { throw ('DLL ausente: '+$dll) }
    Get-FileHash -LiteralPath $dll -Algorithm SHA256
}
