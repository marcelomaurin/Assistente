param([string]$Source = (Join-Path $PSScriptRoot '..\..\CHATGPT'))
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$revision='3c845b998c7c631c0608c12b766a04b39da13be1'
$destination=Join-Path $root '.deps\chatgpt-integration-baseline'
$marker=Join-Path $destination 'ASSISTENTE_BASELINE_COMMIT.txt'
if ((Test-Path -LiteralPath $marker) -and ((Get-Content -LiteralPath $marker -Raw).Trim() -eq $revision)) { return }
if (Test-Path -LiteralPath $destination) { throw 'Diretório de dependência já existe sem identificação válida; preserve-o e informe -ChatGPT explicitamente.' }
$build=Join-Path $root 'build'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$archive=Join-Path $build ('chatgpt-baseline-'+[guid]::NewGuid()+'.zip')
& git -C $Source archive --format=zip ('--output='+$archive) $revision pacote funcoes.pas LICENSE 'OpenSSL License.txt'
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível obter a revisão fixada do checkout CHATGPT. Informe -Source ou -ChatGPT.' }
Expand-Archive -LiteralPath $archive -DestinationPath $destination
Set-Content -LiteralPath $marker -Value $revision -Encoding ascii
Write-Output ('Dependência isolada: '+$destination+' @ '+$revision)
