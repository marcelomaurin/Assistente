"""Verify the actual versioned installer in an isolated directory under build.

Does not register the test installation, create shortcuts, access providers,
or use microphone/camera. Uses the Windows GUI only for this spawned test app.
"""
from pathlib import Path
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
import subprocess
import time
import uuid
import winreg

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--build-code',default='0217')
parser.add_argument('--version',default='0.217')
parser.add_argument('--no-ui',action='store_true',help='Validate extraction, binaries, configuration preservation and uninstall without opening application windows')
OPTIONS=parser.parse_args()
assert len(OPTIONS.build_code)==4 and OPTIONS.build_code.isdigit()
SETUP=ROOT/f'bin/setup_assistente_{OPTIONS.build_code}.exe'
MANIFEST=ROOT/f'bin/setup_assistente_{OPTIONS.build_code}.manifest.json'
BUILD=(ROOT/'build').resolve()
TEST=BUILD/('installer-check-'+str(uuid.uuid4()))
INSTALL=TEST/'app'
REPORT=[]

def run(args,timeout=120,cwd=ROOT,env=None,record_output=True):
    result=subprocess.run([str(a) for a in args],cwd=cwd,env=env,capture_output=True,timeout=timeout)
    text=(result.stdout+result.stderr).decode('utf-8',errors='replace')
    if text.strip() and record_output:REPORT.append(text.strip())
    assert result.returncode==0, (args[0],result.returncode,text)
    return text

def registry_state():
    key=r'Software\Microsoft\Windows\CurrentVersion\Uninstall\{25A25326-C619-4F25-B473-8916AF42FCD1}_is1'
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER,key) as handle:
            return sorted(winreg.EnumValue(handle,i) for i in range(winreg.QueryInfoKey(handle)[1]))
    except FileNotFoundError:return None

def main():
    TEST.mkdir(parents=True)
    assert TEST.resolve().is_relative_to(BUILD) and INSTALL.resolve().is_relative_to(TEST)
    manifest=json.loads(MANIFEST.read_text(encoding='utf-8-sig'))
    assert hashlib.sha256(SETUP.read_bytes()).hexdigest()==manifest['installer']['sha256']
    assert manifest['version']==OPTIONS.version
    before=registry_state()
    (TEST/'registration-before.json').write_text(json.dumps(before,ensure_ascii=False,indent=2),encoding='utf-8')
    args=[SETUP,'/VERYSILENT','/SUPPRESSMSGBOXES','/SP-','/NORESTART','/NOICONS','/TASKS=',
          '/VERIFYINSTALL=1',f'/DIR={INSTALL}',f'/LOG={TEST / "install.log"}']
    run(args)
    assert registry_state()==before,'Validation changed application registration'
    for record in manifest['files']:
        path=(INSTALL/record['path']).resolve()
        assert path.is_relative_to(INSTALL.resolve())
        assert path.stat().st_size==record['size'],record['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest()==record['sha256'],record['path']
    if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 211):
        webview_lock=json.loads((ROOT/'runtime/WebView2/1.0.4314.35/sdk-lock.json').read_text(encoding='utf-8'))
        assert hashlib.sha256((INSTALL/'WebView2Loader.dll').read_bytes()).hexdigest()==webview_lock['files']['x86/WebView2Loader.dll'],'Incorrect WebView2 loader'
        assert (INSTALL/'LICENSES/WebView2.txt').is_file(),'WebView2 license missing'
        REPORT.append('PASS: official pinned WebView2 Win32 loader and redistribution license packaged')
    if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 214):
        info=json.loads((INSTALL/'package-info.json').read_text(encoding='utf-8-sig'))
        assert info['tag_editor_required'] is True and info['tag_editor_executable']=='presentation_editor.exe'
        tag_editor=INSTALL/info['tag_editor_executable']
        assert tag_editor.is_file(),'Required tag editor missing with no optional tasks selected'
        assert hashlib.sha256(tag_editor.read_bytes()).hexdigest()==info['editor_sha256'],'Required tag editor differs from validated build'
        assert (INSTALL/'docs/tags-apresentacoes.md').is_file()
        recipe=(ROOT/'src/assistente.iss').read_text(encoding='utf-8')
        tag_alias=next(line for line in recipe.splitlines() if line.startswith('Name: "{autoprograms}\\Editor de Tags do Assistente";'))
        assert 'presentation_editor.exe' in tag_alias and 'Tasks:' not in tag_alias and 'Components:' not in tag_alias
        REPORT.append('PASS: required tag editor and tag guide installed without optional tasks; dedicated Start Menu alias retained alongside the presentation editor')
    if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 216):
        assert info['presentation_interaction_tags']==['PERGUNTAR','MENU','CONTINUAR']
        assert info['presentation_menu']=={'replaces_media':True,'hover_threshold_ms':5000,'keyboard':True,'scroll_buttons':True}
        assert (INSTALL/'docs/perguntas-apresentacao.md').is_file()
        run([INSTALL/'pva_tool.exe','verify',INSTALL/'examples/perguntas-menu.pva'])
        REPORT.append('PASS: PERGUNTAR/MENU/CONTINUAR metadata, question guide and ready-to-use menu example included')
    catalog=json.loads((INSTALL/'AVATARES/movimentos.json').read_text(encoding='utf-8-sig'))
    # An unchanged catalog from the first 0.210 package must receive fixed aliases.
    catalog_path=INSTALL/'AVATARES/movimentos.json'
    catalog_path.write_bytes((ROOT/'tests/fixtures/movimentos-0210-original.json').read_bytes())
    run(args)
    assert catalog_path.read_bytes()==(ROOT/'AVATARES/movimentos.json').read_bytes(),'Original default catalog did not upgrade'
    REPORT.append('PASS: upgrade replaces the unchanged original catalog with corrected arm aliases')
    if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 212):
        catalog_path.write_bytes((ROOT/'tests/fixtures/movimentos-0211.json').read_bytes())
        run(args)
        assert catalog_path.read_bytes()==(ROOT/'AVATARES/movimentos.json').read_bytes(),'0.211 default catalog did not upgrade'
        REPORT.append('PASS: unchanged 0.211 catalog upgraded to JSON member trajectories')

    if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 213):
        catalog_path.write_bytes((ROOT/'tests/fixtures/movimentos-0212.json').read_bytes())
        collision_path=INSTALL/'AVATARES/colisoes.json'
        collision_path.write_bytes((ROOT/'tests/fixtures/colisoes-0212.json').read_bytes())
        run(args)
        assert catalog_path.read_bytes()==(ROOT/'AVATARES/movimentos.json').read_bytes(),'0.212 movement catalog did not upgrade'
        assert collision_path.read_bytes()==(ROOT/'AVATARES/colisoes.json').read_bytes(),'0.212 collision profile did not upgrade'
        REPORT.append('PASS: both unchanged 0.212 movement and collision JSON files upgraded to the calibrated paths')

    if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 214):
        previous_code='0216' if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 217) else '0215' if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 216) else ('0214' if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 215) else '0213')
        previous_setup=ROOT/f'bin/setup_assistente_{previous_code}.exe'
        previous_manifest=json.loads((ROOT/f'bin/setup_assistente_{previous_code}.manifest.json').read_text(encoding='utf-8-sig'))
        assert hashlib.sha256(previous_setup.read_bytes()).hexdigest()==previous_manifest['installer']['sha256']
        # Test the real previous installer, not a synthetic default fixture.
        catalog_path.unlink();(INSTALL/'AVATARES/colisoes.json').unlink()
        run([previous_setup,*args[1:-1],f'/LOG={TEST / f"upgrade-from-{previous_code}.log"}'])
        previous_hash=next(r['sha256'] for r in previous_manifest['files'] if r['path']=='AVATARES/movimentos.json')
        assert hashlib.sha256(catalog_path.read_bytes()).hexdigest()==previous_hash
        run(args)
        assert catalog_path.read_bytes()==(ROOT/'AVATARES/movimentos.json').read_bytes(),f'{previous_code} default catalog did not upgrade'
        info=json.loads((INSTALL/'package-info.json').read_text(encoding='utf-8-sig'))
        assert info['version']==OPTIONS.version and info['motion_editor_stage']=='preview'
        assert hashlib.sha256((INSTALL/'motion_editor.exe').read_bytes()).hexdigest()==info['motion_editor_sha256']
        assert (INSTALL/'docs/editor-movimentos.md').is_file()
        assert info['motion_format_versions']==[1,2] and info['motion_editor_theme']=='MultiCNC/MultiSuite'
        # Preview exercises the installed executable, installed rig and installed JSON.
        preview_env=dict(os.environ,ASSISTENTE_CONFIG_DIR=str(TEST/'motion-editor-config'),ASSISTENTE_MOVEMENTS_FILE=str(INSTALL/'AVATARES/movimentos.json'))
        run([INSTALL/'motion_editor.exe','--smoke-test'],cwd=INSTALL,env=preview_env,timeout=120)
        assert (INSTALL/'motion-editor-smoke-result.txt').read_text(encoding='utf-8').startswith('PASS:')
        REPORT.append(f'PASS: actual {previous_code}-to-{OPTIONS.build_code} upgrade; installed preview passed real avatar selection, XYZ pose, gizmo drag, save/load, scrub, protected playback and CAD camera views')
        if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 215):
            assert hashlib.sha256((INSTALL/'criador_avatar.exe').read_bytes()).hexdigest()==info['criador_avatar_sha256']
            assert (INSTALL/'runtime/python/python.exe').is_file() and (INSTALL/'tools/avatar_spec.py').is_file()
            assert any((INSTALL/'tools/avatar-source').glob('mh-targets-*.npz')) and (INSTALL/'docs/criador-avatar.md').is_file()
            # The installed generator answers with the installed Python (no network).
            out=subprocess.run([INSTALL/'runtime/python/python.exe','avatar_spec.py','catalog'],cwd=INSTALL/'tools',capture_output=True,timeout=300)
            assert out.returncode==0 and json.loads(out.stdout)['modifiers'],'installed avatar generator failed'
            probe=subprocess.run([INSTALL/'runtime/python/python.exe','-c',
                'import sys,json,numpy,scipy,PIL;print(json.dumps(dict(isolated=sys.flags.isolated,paths=sys.path,numpy=numpy.__version__,scipy=scipy.__version__,Pillow=PIL.__version__)))'],
                cwd=INSTALL,capture_output=True,timeout=45)
            assert probe.returncode==0,probe.stderr
            runtime=json.loads(probe.stdout)
            assert runtime['isolated']==1 and all(Path(path).resolve().is_relative_to(INSTALL.resolve()) for path in runtime['paths']),'Python runtime escaped packaged files'
            assert all(runtime[key]==info['python_runtime'][key] for key in ['numpy','scipy','Pillow'])
            assert info['silence_detection'] is True and info['speech_filter_hz']==[100,7000]
            assert len(info['speech_recognition'])==2
            assert (INSTALL/'docs/reconhecimento-voz.md').is_file()
            REPORT.append('PASS: Criador Avatar and installed generator work with isolated embedded Python; no system/user Python paths; voice/filter metadata and guide included')

    models=list((INSTALL/'AVATARES').glob('*/modelo.gltf'))
    expected_models=len(list((ROOT/'AVATARES').glob('*/modelo.gltf')))
    assert len(models)==expected_models,'Missing bundled models'
    for model in models:
        profile=json.loads((model.parent/'avatar.json').read_text(encoding='utf-8'))
        assert profile['version']==(5 if profile['id']=='ze_gotinha' else 4),'Installer contains old avatar: '+profile['id']
        animations={a['name'] for a in json.loads(model.read_text(encoding='utf-8'))['animations']}
        assert all(not m.get(k) or m[k] in animations for m in catalog['movements'] for k in ('clip','talking_clip')),'Installed avatar lacks catalog animations: '+profile['id']
        current=ROOT/'AVATARES'/profile['id']/'modelo.gltf'
        assert hashlib.sha256(model.read_bytes()).digest()==hashlib.sha256(current.read_bytes()).digest(),'Installer model differs from validated source'
    REPORT.append(f'PASS: all {expected_models} installed avatars are current (Zé Gotinha v5, others v4) and match the validated source models byte for byte')
    assert not (INSTALL/'Setmain.cfg').exists() and not (INSTALL/'conversation-history.json').exists()
    REPORT.append(f'PASS: actual installer extracted {len(manifest["files"])} files; all SHA-256 hashes match; {expected_models} avatars; no personal configuration')

    # Use the same Win32 FPC SSL loader as the application against the DLLs
    # extracted by the installer, without making any network request.
    # Avoid Windows' legacy elevation heuristic for unmanifested programs
    # whose executable name contains "installer".
    fpc_path = r'C:\FPC\3.2.2\bin\i386-win32\fpc.exe'
    if not Path(fpc_path).exists():
        fpc_path = r'C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe'
    run([fpc_path,'-MObjFPC','-Scghi',f'-FU{TEST}',f'-FE{TEST}','-Fu'+str(ROOT/'src'),
         '-ossl_runtime_probe.exe',ROOT/'tests/installer_ssl_check.lpr'],record_output=False)
    run([TEST/'ssl_runtime_probe.exe',INSTALL],cwd=INSTALL)
    if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 213):
        run([fpc_path,'-MObjFPC','-Scghi',f'-FU{TEST}',f'-FE{TEST}','-Fu'+str(ROOT/'src'),
             ROOT/'tests/movement_completion_probe.lpr'],record_output=False)
        movement_env=dict(os.environ,ASSISTENTE_MOVEMENTS_FILE=str(INSTALL/'AVATARES/movimentos.json'))
        for mode in ['fresh','sequence']:
            text=run([TEST/'movement_completion_probe.exe','ze_gotinha','1.3708040416240692',mode],cwd=INSTALL,env=movement_env,timeout=240,record_output=False)
            assert 'PROFILE ze_gotinha incomplete=0' in text,'Installed movements did not complete: '+mode
        REPORT.append('PASS: actual installed JSON/rig/profile completed all 53 Ze Gotinha movements independently and in sequence with collision protection active')


    if not OPTIONS.no_ui:
        config=TEST/'isolated-config';config.mkdir()
        (config/'Setmain.cfg').write_text('CONTINUOUS_LISTENING:0\nAUTOSPEAK:0\nVISION_SOURCE:none\nAVATAR3D_PROFILE:ze_gotinha\nAVATAR3D_AUTO_IDLE:1\n',encoding='utf-8')
        for executable,title_prefix in [('assistente.exe','Assistente |'),('presentation_editor.exe','Assistente | Editor de Apresentações')]:
            launch=[str(INSTALL/executable)]
            if executable=='assistente.exe' and tuple(map(int, OPTIONS.version.split('.'))) >= (0,216):
                launch+=['--presentation-silent',str(INSTALL/'examples/perguntas-menu.pva')]
            process=subprocess.Popen(launch,cwd=INSTALL,
                                     env=dict(os.environ,ASSISTENTE_CONFIG_DIR=str(config)))
            user32=ctypes.WinDLL('user32',use_last_error=True)
            callback_type=ctypes.WINFUNCTYPE(wintypes.BOOL,wintypes.HWND,wintypes.LPARAM)
            user32.EnumWindows.argtypes=[callback_type,wintypes.LPARAM]
            user32.GetWindowThreadProcessId.argtypes=[wintypes.HWND,ctypes.POINTER(wintypes.DWORD)]
            user32.GetWindowTextW.argtypes=[wintypes.HWND,wintypes.LPWSTR,ctypes.c_int]
            user32.IsWindowVisible.argtypes=[wintypes.HWND]
            user32.PostMessageW.argtypes=[wintypes.HWND,wintypes.UINT,wintypes.WPARAM,wintypes.LPARAM]
            windows=[]
            @callback_type
            def enum_window(hwnd,_):
                pid=wintypes.DWORD();user32.GetWindowThreadProcessId(hwnd,ctypes.byref(pid))
                title=ctypes.create_unicode_buffer(512);user32.GetWindowTextW(hwnd,title,512)
                if pid.value==process.pid and user32.IsWindowVisible(hwnd) and title.value.startswith(title_prefix):
                    windows.append(hwnd)
                return True
            try:
                deadline=time.monotonic()+25
                while not windows and time.monotonic()<deadline and process.poll() is None:
                    user32.EnumWindows(enum_window,0);time.sleep(.2)
                assert windows and process.poll() is None,'Installed application failed to show its main form'
                if executable=='assistente.exe' and tuple(map(int, OPTIONS.version.split('.'))) >= (0,216):
                    user32.EnumChildWindows.argtypes=[wintypes.HWND,callback_type,wintypes.LPARAM]
                    user32.GetClassNameW.argtypes=[wintypes.HWND,wintypes.LPWSTR,ctypes.c_int]
                    user32.SendMessageW.argtypes=[wintypes.HWND,wintypes.UINT,wintypes.WPARAM,wintypes.LPARAM]
                    user32.SendMessageW.restype=wintypes.LPARAM
                    children=[]
                    @callback_type
                    def inspect_question_control(hwnd,_):
                        if user32.IsWindowVisible(hwnd):
                            text=ctypes.create_unicode_buffer(2048);kind=ctypes.create_unicode_buffer(256)
                            user32.GetWindowTextW(hwnd,text,2048);user32.GetClassNameW(hwnd,kind,256)
                            children.append((hwnd,kind.value,text.value))
                        return True
                    deadline=time.monotonic()+15
                    while time.monotonic()<deadline:
                        children.clear();user32.EnumChildWindows(windows[0],inspect_question_control,0)
                        if any(t=='Continuar' for _,_,t in children):break
                        time.sleep(.1)
                    assert any(t=='Continuar' for _,_,t in children),'Installed PERGUNTAR did not pause'
                    user32.GetWindowLongW.argtypes=[wintypes.HWND,ctypes.c_int]
                    user32.GetWindowLongW.restype=ctypes.c_long
                    edit=next(hwnd for hwnd,kind,_ in children if kind.lower()=='edit' and not (user32.GetWindowLongW(hwnd,-16)&0x0804))
                    command=ctypes.create_unicode_buffer('MENU')
                    user32.SendMessageW(edit,0x000C,0,ctypes.addressof(command))
                    user32.PostMessageW(edit,0x0100,0x0D,0)
                    deadline=time.monotonic()+10
                    while time.monotonic()<deadline:
                        children.clear();user32.EnumChildWindows(windows[0],inspect_question_control,0)
                        if any('Rolar para baixo' in t for _,_,t in children):break
                        time.sleep(.1)
                    assert any('Rolar para cima' in t for _,_,t in children) and any('Rolar para baixo' in t for _,_,t in children),'Installed MENU did not show scrolling controls'
                    lists=[hwnd for hwnd,kind,_ in children if kind.lower().endswith('listbox')]
                    assert any(user32.SendMessageW(hwnd,0x018B,0,0)>=2 for hwnd in lists),'Installed MENU has no selectable blocks'
                    REPORT.append('PASS: actual installed Assistant opened example, paused at PERGUNTAR and displayed MENU blocks with both scroll controls from typed input')
                if executable == 'presentation_editor.exe':
                    child_texts=[]
                    user32.EnumChildWindows.argtypes=[wintypes.HWND,callback_type,wintypes.LPARAM]
                    @callback_type
                    def enum_child(hwnd,_):
                        text=ctypes.create_unicode_buffer(2048)
                        user32.GetWindowTextW(hwnd,text,2048)
                        child_texts.append(text.value)
                        return True
                    user32.EnumChildWindows(windows[0],enum_child,0)
                    assert str(INSTALL/'assistente.exe').lower() in [t.lower() for t in child_texts], 'Editor did not select installed Assistant'
                time.sleep(2)
                assert process.poll() is None,'Installed application closed unexpectedly'
                assert user32.PostMessageW(windows[0],0x0010,0,0),'Unable to close owned test window'
                assert process.wait(timeout=15)==0,'Installed application shutdown failed'
                assert not (INSTALL/'crash.log').exists(),'Installed application produced a crash report'
            finally:
                if process.poll() is None:process.kill();process.wait()
            REPORT.append(f'PASS: installed {executable} opened and closed normally with isolated configuration; editor selects adjacent Assistant')

    else:
        REPORT.append('SKIP: interactive application-window checks disabled (--no-ui); packaged files and console tools are still verified')

    run([INSTALL/'pva_tool.exe','selftest'])
    sample=TEST/'sample.pva'
    run([INSTALL/'pva_tool.exe','pack',ROOT/'examples/apresentacoes/blocos-eventos.txt',TEST,sample])
    run([INSTALL/'pva_tool.exe','verify',sample])
    REPORT.append('PASS: installed PVA tool selftest and block/event example pack/verify')

    # Reinstall the same actual package and ensure user-created data is kept.
    personal_avatar=INSTALL/'AVATARES/avatar-pessoal-validacao'
    personal_avatar.mkdir(exist_ok=True)
    personal_avatar_file=personal_avatar/'preservar.json'
    personal_avatar_file.write_text('{"user-avatar":true}\n',encoding='utf-8')
    sentinels={'conversation-history.json':'{"installer-test":"preserve"}\n','Setmain.cfg':'installer-test-preserve\n'}
    for name,text in sentinels.items():(INSTALL/name).write_text(text,encoding='utf-8')
    catalog_path=INSTALL/'AVATARES/movimentos.json'
    catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
    catalog['movements'].append({'id':'instalador_preservar','tag':'gesto personalizado do usuario','title':'Movimento do usuario','mode':'pose','clip':'idle'})
    catalog_text=json.dumps(catalog,ensure_ascii=False,indent=2)+'\n';catalog_path.write_text(catalog_text,encoding='utf-8')
    collision_path=INSTALL/'AVATARES/colisoes.json'
    collision_text=collision_path.read_text(encoding='utf-8')+'\n'
    collision_path.write_text(collision_text,encoding='utf-8')
    external_path=INSTALL/'AVATARES/movimentos/aceno.json'
    if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 214):
        external=json.loads(external_path.read_text(encoding='utf-8'));external['name']='Aceno personalizado do usuario'
        external_text=json.dumps(external,ensure_ascii=False,indent=2)+'\n';external_path.write_text(external_text,encoding='utf-8')
        new_external=external_path.parent/'gesto-pessoal.json';new_external.write_text(external_text,encoding='utf-8')
    run(args)
    if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 214):
        assert external_path.read_text(encoding='utf-8')==external_text,'Reinstall overwrote edited external motion'
        assert new_external.read_text(encoding='utf-8')==external_text,'Reinstall overwrote a new external motion'
        REPORT.append('PASS: reinstall preserved edited external animations and new user-created motion JSON')
    assert personal_avatar_file.read_text(encoding='utf-8')=='{"user-avatar":true}\n','Reinstall removed user avatar'
    assert collision_path.read_text(encoding='utf-8')==collision_text,'Reinstall overwrote collision configuration'
    assert catalog_path.read_text(encoding='utf-8')==catalog_text,'Reinstall overwrote custom JSON movements'
    for name,text in sentinels.items():assert (INSTALL/name).read_text(encoding='utf-8')==text,name
    assert registry_state()==before
    if tuple(map(int, OPTIONS.version.split('.'))) >= (0, 214):
        assert (INSTALL/'presentation_editor.exe').is_file(),'Reinstall removed required tag editor'
        assert hashlib.sha256((INSTALL/'presentation_editor.exe').read_bytes()).hexdigest()==info['editor_sha256']
        REPORT.append('PASS: required tag/presentation editor remains installed after upgrade and reinstall')
    REPORT.append('PASS: reinstall preserved user configuration/history, custom shared JSON movements and application registration')

    uninstallers=list(INSTALL.glob('unins*.exe'))
    assert len(uninstallers)==1 and uninstallers[0].resolve().is_relative_to(TEST.resolve())
    run([uninstallers[0],'/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',f'/LOG={TEST / "uninstall.log"}'])
    deadline=time.monotonic()+15
    while (INSTALL/'assistente.exe').exists() and time.monotonic()<deadline:time.sleep(.2)
    for record in manifest['files']:
        preserved=record['path'] in ['AVATARES/movimentos.json','AVATARES/colisoes.json'] or (tuple(map(int, OPTIONS.version.split('.'))) >= (0,214) and record['path'].startswith('AVATARES/movimentos/'))
        if not preserved:assert not (INSTALL/record['path']).exists(),record['path']
    assert personal_avatar_file.read_text(encoding='utf-8')=='{"user-avatar":true}\n','Uninstall removed user avatar'
    assert catalog_path.read_text(encoding='utf-8')==catalog_text,'Uninstall deleted custom movements'
    for name,text in sentinels.items():assert (INSTALL/name).read_text(encoding='utf-8')==text,name
    if tuple(map(int, OPTIONS.version.split('.'))) >= (0,214):
        assert external_path.read_text(encoding='utf-8')==external_text,'Uninstall deleted edited external animation'
        assert new_external.read_text(encoding='utf-8')==external_text,'Uninstall deleted new user animation'
        REPORT.append('PASS: uninstall preserved external motion JSON edited or created with the preview editor')
    assert registry_state()==before
    REPORT.append('PASS: uninstaller removed application binaries, preserved user files and JSON movements, and did not change registration')
    result={'version':OPTIONS.version,'installer_sha256':manifest['installer']['sha256'],'result':'PASS','environment':'Windows native; isolated verification installation',
            'limitations':['Physical microphone, camera, Kinect and live recognition/AI accounts not exercised'],
            'payload_files':len(manifest['files']),'profiles':len(list((ROOT/'AVATARES').glob('*/modelo.gltf'))),'checks':REPORT}
    path=ROOT/f'bin/setup_assistente_{OPTIONS.build_code}.validacao.json'
    path.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('\n'.join(REPORT));print(f'Validation report: {path}')

if __name__=='__main__':main()
