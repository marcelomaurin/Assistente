param([string]$Destination = (Join-Path $PSScriptRoot '..\.deps\castle-engine'))
$ErrorActionPreference = 'Stop'
$commit = '6a433378a8cc7117f5deccbec2fb70a42fdb98f3'
if (Test-Path -LiteralPath $Destination) {
    $head = & git -C $Destination rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $head -ne $commit) { throw 'Destino existente não corresponde ao Castle fixado. Escolha outro destino.' }
} else {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    & git -C $Destination init
    if ($LASTEXITCODE -ne 0) { throw 'git init falhou' }
    & git -C $Destination remote add origin https://github.com/castle-engine/castle-engine.git
    if ($LASTEXITCODE -ne 0) { throw 'Configuração do remoto falhou' }
    & git -C $Destination fetch --depth 1 origin $commit
    if ($LASTEXITCODE -ne 0) { throw 'Download do Castle falhou' }
    & git -C $Destination checkout --detach FETCH_HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Checkout do Castle falhou' }
}
Write-Output "Castle: $Destination ($commit)"
Write-Output 'No Lazarus, abra packages\lazarus\castle_engine_lcl.lpk e adicione o pacote ao projeto.'
