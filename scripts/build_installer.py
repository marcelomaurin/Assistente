"""Build the Windows installer (Inno Setup) from compiled programs.

Same steps as build_installer.ps1, plus the Criador Avatar, the avatar tools
and the embedded Python runtime. Runs on Windows or on Linux with ISCC under
Wine:

    python scripts/build_installer.py --version 0.217 --build-code 0217 --python-runtime <dir> \
        [--programs build/presentation-questions] [--iscc "wine C:\\InnoSetup\\ISCC.exe"]
"""
import argparse, hashlib, json, os, shlex, shutil, subprocess, sys, uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROGRAMS = ['assistente.exe', 'presentation_editor.exe', 'pva_tool.exe', 'motion_editor.exe', 'criador_avatar.exe']
TOOLS = ['avatar_spec.py', 'game_avatar.py', 'professora_avatar.py', 'ze_gotinha_avatar.py', 'glb_import.py',
         'tripo_client.py', 'tripo_rig_import.py', 'repair_movement_paths.py', 'export_movement_timelines.py', 'generate_professor.py',
         'pack_mh_targets.py', 'avatar-requirements.txt']
FORBIDDEN = {'Setmain.cfg', 'conversation-history.json', 'crash.log'}


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def winpath(p):
    """Path as seen by ISCC (Wine maps / to Z:)."""
    return str(p) if os.name == 'nt' else 'Z:' + str(Path(p).resolve()).replace('/', '\\')


def main():
    a = argparse.ArgumentParser(description=__doc__)
    a.add_argument('--version', default='0.217'); a.add_argument('--build-code', default='0217')
    a.add_argument('--programs', type=Path); a.add_argument('--python-runtime', type=Path, required=True)
    a.add_argument('--chatgpt', type=Path); a.add_argument('--castle', type=Path)
    a.add_argument('--iscc', default=r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe')
    o = a.parse_args()
    programs = (o.programs or ROOT / f'build/presentations-{o.build_code}').resolve()
    chat = (o.chatgpt or ROOT / '.deps/chatgpt-integration-baseline').resolve()
    castle = (o.castle or Path(os.environ.get('CASTLE_ENGINE_PATH', ROOT / '.deps/castle-engine'))).resolve()
    for name in PROGRAMS:
        if not (programs / name).is_file():
            sys.exit(f'Compile primeiro (ausente: {programs / name})')
    if not (o.python_runtime / ('python.exe')).is_file():
        sys.exit(f'Python embutido ausente: {o.python_runtime}')
    work = ROOT / f'build/installer_{o.build_code}' / f'stage-{uuid.uuid4()}'
    payload = work / 'payload'
    (payload / 'docs').mkdir(parents=True); (payload / 'LICENSES').mkdir()
    for name in PROGRAMS:
        shutil.copy2(programs / name, payload / name)
    shutil.copytree(ROOT / 'AVATARES', payload / 'AVATARES')
    for f in (payload / 'AVATARES').rglob('*'):
        if f.is_dir() and f.name == '__pycache__':
            shutil.rmtree(f)
    shutil.copy2(ROOT / 'runtime/WebView2/1.0.4314.35/x86/WebView2Loader.dll', payload)
    shutil.copy2(ROOT / 'runtime/WebView2/1.0.4314.35/LICENSE.txt', payload / 'LICENSES/WebView2.txt')
    for name in ('libcrypto-1_1.dll', 'libssl-1_1.dll', 'libeay32.dll', 'ssleay32.dll'):
        shutil.copy2(ROOT / 'src' / name, payload)
    for f in (ROOT / 'Docs').rglob('*.md'):
        dest = payload / 'docs' / f.relative_to(ROOT / 'Docs'); dest.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(f, dest)
    shutil.copytree(ROOT / 'examples/apresentacoes', payload / 'examples')
    shutil.copy2(ROOT / 'examples/perguntas-menu.script', payload / 'examples/perguntas-menu.script')
    subprocess.run(([] if os.name == 'nt' else ['wine']) + [str(payload / 'pva_tool.exe'), 'pack', str(payload / 'examples/perguntas-menu.script'),
                    str(payload / 'examples'), str(payload / 'examples/perguntas-menu.pva')], check=True, capture_output=True)
    shutil.copy2(chat / 'LICENSE', payload / 'LICENSES/CHATGPT-GPL-3.0.txt')
    shutil.copy2(chat / 'OpenSSL License.txt', payload / 'LICENSES/OpenSSL.txt')
    shutil.copytree(castle / 'doc/licenses', payload / 'LICENSES/Castle')
    # Avatar generator (Criador Avatar) and its CC0 sources.
    (payload / 'tools').mkdir()
    for name in TOOLS:
        shutil.copy2(ROOT / 'tools' / name, payload / 'tools' / name)
    shutil.copytree(ROOT / 'tools/avatar-source', payload / 'tools/avatar-source')
    shutil.copy2(ROOT / 'tools/avatar-source/LICENSE.ASSETS.md', payload / 'LICENSES/MakeHuman-assets-CC0.md')
    shutil.copytree(o.python_runtime, payload / 'runtime/python', ignore=shutil.ignore_patterns('__pycache__', '*.pdb'))
    shutil.copy2(o.python_runtime / 'LICENSE.txt', payload / 'LICENSES/Python.txt')
    catalog = json.loads((payload / 'AVATARES/movimentos.json').read_text(encoding='utf-8'))
    if catalog.get('version') not in (1, 2) or not catalog.get('movements'):
        sys.exit('Catálogo de movimentos inválido.')
    models = sorted((payload / 'AVATARES').glob('*/modelo.gltf'))
    for model in models:
        clips = {x['name'] for x in json.loads(model.read_text(encoding='utf-8'))['animations']}
        for m in catalog['movements']:
            for clip in (m.get('clip'), m.get('talking_clip')):
                if clip and clip not in clips:
                    sys.exit(f"Movimento sem animação: {m['id']} / {model.parent.name} / {clip}")
    rev = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
    dirty = bool(subprocess.run(['git', '-C', str(ROOT), 'status', '--porcelain'], capture_output=True, text=True).stdout.strip())
    runtime_probe = subprocess.run(([] if os.name == 'nt' else ['wine']) + [str(payload / 'runtime/python/python.exe'), '-B', '-c',
        'import sys,json,numpy,scipy,PIL;print(json.dumps(dict(python=sys.version.split()[0],numpy=numpy.__version__,scipy=scipy.__version__,Pillow=PIL.__version__,isolated=sys.flags.isolated,paths=sys.path)))'],
        capture_output=True, timeout=45)
    if runtime_probe.returncode:
        sys.exit('Python empacotado invalido: ' + runtime_probe.stderr.decode(errors='replace'))
    runtime_info = json.loads(runtime_probe.stdout)
    def host_path(path):
        # Under Wine the probe reports Z:\\... paths for this Linux tree.
        if os.name != 'nt' and path[:2].upper() == 'Z:':
            return Path(path[2:].replace('\\', '/'))
        return Path(path)
    if runtime_info['isolated'] != 1 or any(not host_path(path).resolve().is_relative_to(payload.resolve()) for path in runtime_info['paths']):
        sys.exit('O Python do pacote depende de arquivos fora do instalador.')
    voice_source = json.loads((ROOT / 'vendor/chatgpt-voice/chrome-speech-source.json').read_text(encoding='utf-8'))
    shutil.copy2(ROOT / 'vendor/chatgpt-voice/chrome-speech-source.json', payload / 'docs/voice-source-sha256.json')
    info = {'version': o.version, 'source_commit': rev, 'source_dirty': dirty, 'platform': 'i386-win32',
            'executable_sha256': sha(programs / 'assistente.exe'), 'editor_sha256': sha(programs / 'presentation_editor.exe'),
            'tool_sha256': sha(programs / 'pva_tool.exe'), 'motion_editor_sha256': sha(programs / 'motion_editor.exe'),
            'criador_avatar_sha256': sha(programs / 'criador_avatar.exe'),
            'presentation_interaction_tags': ['PERGUNTAR', 'MENU', 'CONTINUAR'],
            'presentation_menu': {'replaces_media': True, 'hover_threshold_ms': 5000, 'keyboard': True, 'scroll_buttons': True},
            'tag_editor_required': True, 'tag_editor_executable': 'presentation_editor.exe',
            'motion_editor_stage': 'preview', 'motion_format_versions': [1, 2], 'motion_editor_theme': 'MultiCNC/MultiSuite',
            'avatar_profiles': len(models), 'avatar_spec_format': 'assistente-avatar-spec/1',
            'python_runtime': {key: value for key, value in runtime_info.items() if key != 'paths'},
            'speech_recognition': ['Chrome Web Speech (no API key)', 'OpenAI Whisper (STT token or ChatGPT token)'],
            'speech_filter_hz': [100, 7000], 'silence_detection': True,
            'voice_source_sha256': voice_source['files'],
            'source_url': 'https://github.com/marcelomaurin/Assistente',
            'chatgpt_source': 'https://github.com/marcelomaurin/CHATGPT/tree/3c845b998c7c631c0608c12b766a04b39da13be1',
            'castle_source': 'https://github.com/castle-engine/castle-engine/tree/6a433378a8cc7117f5deccbec2fb70a42fdb98f3',
            'makehuman_targets': 'https://github.com/makehumancommunity/makehuman (CC0 assets)'}
    (payload / 'package-info.json').write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding='utf-8')
    records = []
    for f in sorted(p for p in payload.rglob('*') if p.is_file()):
        rel = f.relative_to(payload).as_posix()
        if f.name in FORBIDDEN or (f.suffix in ('.ppu', '.o', '.lps', '.cfg') and not rel.startswith('runtime/python/')):
            sys.exit(f'Arquivo pessoal/de build no payload: {rel}')
        records.append({'path': rel, 'size': f.stat().st_size, 'sha256': sha(f)})
    out = work / 'output'; out.mkdir()
    log = ROOT / f'build/installer_{o.build_code}/compile.log'
    compiler_command = [o.iscc] if Path(o.iscc).is_file() else shlex.split(o.iscc, posix=os.name != 'nt')
    cmd = compiler_command + [
        '/O' + winpath(out), f'/DMyAppVersion={o.version}', f'/DSetupCode={o.build_code}',
        '/DPackageDir=' + winpath(payload), '/DRepositoryDir=' + winpath(ROOT), winpath(ROOT / 'src/assistente.iss')]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_bytes(proc.stdout)
    if proc.returncode:
        sys.exit(f'Falha no Inno Setup. Consulte {log}')
    name = f'setup_assistente_{o.build_code}'
    setup = ROOT / 'bin' / f'{name}.exe'
    shutil.move(out / f'{name}.exe', setup)
    manifest = {'schema': 1, 'version': o.version, 'source_commit': rev, 'platform': 'i386-win32',
                'installer': {'file': f'{name}.exe', 'size': setup.stat().st_size, 'sha256': sha(setup)}, 'files': records}
    (ROOT / 'bin' / f'{name}.manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Instalador:', setup)
    print('Arquivos empacotados:', len(records))
    print('Payload:', payload)


if __name__ == '__main__':
    main()
