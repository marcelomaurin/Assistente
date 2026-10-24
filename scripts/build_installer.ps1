param(
    [ValidatePattern('^[0-9]+\.[0-9]{3}$')][string]$Version = '0.214',
    [ValidatePattern('^[0-9]{4}$')][string]$BuildCode = '0214',
    [string]$Compiler = 'C:\Program Files\Inno Setup 7\ISCC.exe',
    [string]$Executable = '',
    [string]$Editor = '',
    [string]$Tool = '',
    [string]$MotionEditor = '',
    [string]$CastleLicenses = '',
    [string]$Castle = $env:CASTLE_ENGINE_PATH,
    [string]$ChatGPT = ''
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $Executable) { $Executable = Join-Path $root ('build\presentations-' + $BuildCode + '\assistente.exe') }
if (-not $Editor) { $Editor = Join-Path $root ('build\presentations-' + $BuildCode + '\presentation_editor.exe') }
if (-not $Tool) { $Tool = Join-Path $root ('build\presentations-' + $BuildCode + '\pva_tool.exe') }
if (-not $MotionEditor) { $MotionEditor = Join-Path $root ('build\presentations-' + $BuildCode + '\motion_editor.exe') }
if (-not $ChatGPT) {
    $ChatGPT = Join-Path $root '.deps\chatgpt-integration-baseline'
    if (-not (Test-Path -LiteralPath $ChatGPT)) { $ChatGPT = Join-Path $root '..\CHATGPT' }
}
if (-not $CastleLicenses) {
    if (-not $Castle) { $Castle = Join-Path $root '.deps\castle-engine' }
    $CastleLicenses = Join-Path $Castle 'doc\licenses'
}
$CastleLicenses = (Resolve-Path -LiteralPath $CastleLicenses).Path
$ChatGPT = (Resolve-Path -LiteralPath $ChatGPT).Path
if (-not (Test-Path -LiteralPath $Compiler)) {
    if (Test-Path 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe') {
        $Compiler = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
    } elseif (Test-Path 'C:\Program Files\Inno Setup 6\ISCC.exe') {
        $Compiler = 'C:\Program Files\Inno Setup 6\ISCC.exe'
    }
}
if (-not (Test-Path -LiteralPath $Compiler)) { throw "Inno Setup ausente: $Compiler" }
foreach ($binary in @($Executable,$Editor,$Tool,$MotionEditor)) {
    if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw "Compile primeiro: python scripts/build_presentations.py --release --out build/presentations-$BuildCode (ausente: $binary)" }
}
$work = Join-Path $root (('build\installer_' + $BuildCode + '\stage-') + [guid]::NewGuid())
$payload = Join-Path $work 'payload'
New-Item -ItemType Directory -Force -Path $payload,(Join-Path $payload 'docs'),(Join-Path $payload 'LICENSES') | Out-Null
Copy-Item -LiteralPath $Executable -Destination (Join-Path $payload 'assistente.exe')
Copy-Item -LiteralPath $Editor -Destination (Join-Path $payload 'presentation_editor.exe')
Copy-Item -LiteralPath $Tool -Destination (Join-Path $payload 'pva_tool.exe')
Copy-Item -LiteralPath $MotionEditor -Destination (Join-Path $payload 'motion_editor.exe')
Copy-Item -LiteralPath (Join-Path $root 'AVATARES') -Destination $payload -Recurse
Copy-Item -LiteralPath (Join-Path $root 'runtime\WebView2\1.0.4314.35\x86\WebView2Loader.dll') -Destination $payload
Copy-Item -LiteralPath (Join-Path $root 'runtime\WebView2\1.0.4314.35\LICENSE.txt') -Destination (Join-Path $payload 'LICENSES\WebView2.txt')
foreach ($name in @('libcrypto-1_1.dll','libssl-1_1.dll','libeay32.dll','ssleay32.dll')) {
    Copy-Item -LiteralPath (Join-Path $root ('src\' + $name)) -Destination $payload
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root 'Docs') -Filter '*.md' -File -Recurse) {
    $relative = $file.FullName.Substring((Join-Path $root 'Docs').Length + 1)
    $destination = Join-Path (Join-Path $payload 'docs') $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
}
Copy-Item -LiteralPath (Join-Path $root 'examples\apresentacoes') -Destination (Join-Path $payload 'examples') -Recurse
Copy-Item -LiteralPath (Join-Path $ChatGPT 'LICENSE') -Destination (Join-Path $payload 'LICENSES\CHATGPT-GPL-3.0.txt')
Copy-Item -LiteralPath (Join-Path $ChatGPT 'OpenSSL License.txt') -Destination (Join-Path $payload 'LICENSES\OpenSSL.txt')
Copy-Item -LiteralPath $CastleLicenses -Destination (Join-Path $payload 'LICENSES\Castle') -Recurse
$movementCatalogPath = Join-Path $payload 'AVATARES\movimentos.json'
$movementCatalog = Get-Content -LiteralPath $movementCatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (($movementCatalog.version -notin @(1,2)) -or $movementCatalog.movements.Count -eq 0) { throw 'Catalogo de movimentos invalido.' }
foreach ($movementModel in Get-ChildItem -LiteralPath (Join-Path $payload 'AVATARES') -Filter 'modelo.gltf' -File -Recurse) {
    $modelClips = (Get-Content -LiteralPath $movementModel.FullName -Raw -Encoding UTF8 | ConvertFrom-Json).animations.name
    foreach ($movementDefinition in $movementCatalog.movements) {
        foreach ($movementClip in @($movementDefinition.clip, $movementDefinition.talking_clip)) {
            if ($movementClip -and ($modelClips -cnotcontains $movementClip)) {
                throw ('Movimento sem animacao: ' + $movementDefinition.id + ' / ' + $movementModel.Directory.Name + ' / ' + $movementClip)
            }
        }
    }
}

$revision = (& git -c ('safe.directory=' + $root.Replace('\','/')) -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel identificar o commit de origem.' }
$info = [ordered]@{
    version = $Version; source_commit = $revision; source_dirty = [bool](& git -C $root status --porcelain); platform = 'i386-win32'
    executable_sha256 = (Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash.ToLowerInvariant()
    editor_sha256 = (Get-FileHash -LiteralPath $Editor -Algorithm SHA256).Hash.ToLowerInvariant()
    tool_sha256 = (Get-FileHash -LiteralPath $Tool -Algorithm SHA256).Hash.ToLowerInvariant()
    motion_editor_sha256 = (Get-FileHash -LiteralPath $MotionEditor -Algorithm SHA256).Hash.ToLowerInvariant()
    tag_editor_required = $true
    tag_editor_executable = 'presentation_editor.exe'
    motion_editor_stage = 'preview'
    motion_format_versions = @(1,2)
    motion_editor_theme = 'MultiCNC/MultiSuite'
    source_url = 'https://github.com/marcelomaurin/Assistente'
    chatgpt_source = 'https://github.com/marcelomaurin/CHATGPT/tree/3c845b998c7c631c0608c12b766a04b39da13be1'
    castle_source = 'https://github.com/castle-engine/castle-engine/tree/6a433378a8cc7117f5deccbec2fb70a42fdb98f3'
}
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $payload 'package-info.json'), ($info | ConvertTo-Json -Depth 5), $utf8)
$records = @()
foreach ($file in Get-ChildItem -LiteralPath $payload -File -Recurse | Sort-Object FullName) {
    $relative = $file.FullName.Substring($payload.Length + 1).Replace('\','/')
    if ($file.Name -match '^(Setmain\.cfg|conversation-history\.json|crash\.log)$' -or $file.Extension -in @('.ppu','.o','.lps','.cfg')) {
        throw "Arquivo pessoal/de build no payload: $relative"
    }
    $records += [ordered]@{path=$relative; size=$file.Length; sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
}
$log = Join-Path $root ('build\installer_' + $BuildCode + '\compile.log')
$compileOutput = Join-Path $work 'output'
New-Item -ItemType Directory -Path $compileOutput | Out-Null
& $Compiler ('/O' + $compileOutput) ('/DMyAppVersion=' + $Version) ('/DSetupCode=' + $BuildCode) ('/DPackageDir=' + $payload) ('/DRepositoryDir=' + $root) (Join-Path $root 'src\assistente.iss') 2>&1 | Tee-Object -FilePath $log
if ($LASTEXITCODE -ne 0) { throw "Falha no Inno Setup. Consulte $log" }
$setupName = 'setup_assistente_' + $BuildCode
$setup = Join-Path $root ('bin\' + $setupName + '.exe')
Move-Item -LiteralPath (Join-Path $compileOutput ($setupName + '.exe')) -Destination $setup -Force
$manifest = [ordered]@{schema=1; version=$Version; source_commit=$revision; platform='i386-win32'
    installer=[ordered]@{file=($setupName + '.exe');size=(Get-Item -LiteralPath $setup).Length;sha256=(Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()}
    files=$records}
[IO.File]::WriteAllText((Join-Path $root ('bin\' + $setupName + '.manifest.json')), ($manifest | ConvertTo-Json -Depth 8), $utf8)
Write-Output "Instalador: $setup"
Write-Output ("Arquivos empacotados: " + $records.Count)
