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
parser.add_argument('--build-code',default='0210')
parser.add_argument('--version',default='0.210')
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
    catalog=json.loads((INSTALL/'AVATARES/movimentos.json').read_text(encoding='utf-8-sig'))
    # An unchanged catalog from the first 0.210 package must receive fixed aliases.
    catalog_path=INSTALL/'AVATARES/movimentos.json'
    catalog_path.write_bytes((ROOT/'tests/fixtures/movimentos-0210-original.json').read_bytes())
    run(args)
    assert catalog_path.read_bytes()==(ROOT/'AVATARES/movimentos.json').read_bytes(),'Original default catalog did not upgrade'
    REPORT.append('PASS: upgrade replaces the unchanged original catalog with corrected arm aliases')
    models=list((INSTALL/'AVATARES').glob('*/modelo.gltf'))
    assert len(models)==11,'Missing bundled models'
    for model in models:
        profile=json.loads((model.parent/'avatar.json').read_text(encoding='utf-8'))
        assert profile['version']==(5 if profile['id']=='ze_gotinha' else 4),'Installer contains old avatar: '+profile['id']
        animations={a['name'] for a in json.loads(model.read_text(encoding='utf-8'))['animations']}
        assert all(not m.get(k) or m[k] in animations for m in catalog['movements'] for k in ('clip','talking_clip')),'Installed avatar lacks catalog animations: '+profile['id']
        current=ROOT/'AVATARES'/profile['id']/'modelo.gltf'
        assert hashlib.sha256(model.read_bytes()).digest()==hashlib.sha256(current.read_bytes()).digest(),'Installer model differs from validated source'
    REPORT.append('PASS: all eleven installed avatars are current (Zé Gotinha v5, others v4) and match the validated source models byte for byte')
    assert not (INSTALL/'Setmain.cfg').exists() and not (INSTALL/'conversation-history.json').exists()
    REPORT.append(f'PASS: actual installer extracted {len(manifest["files"])} files; all SHA-256 hashes match; eleven avatars; no personal configuration')

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

    if not OPTIONS.no_ui:
        config=TEST/'isolated-config';config.mkdir()
        (config/'Setmain.cfg').write_text('CONTINUOUS_LISTENING:0\nAUTOSPEAK:0\nVISION_SOURCE:none\nAVATAR3D_PROFILE:ze_gotinha\nAVATAR3D_AUTO_IDLE:1\n',encoding='utf-8')
        for executable,title_prefix in [('assistente.exe','Assistente |'),('presentation_editor.exe','Assistente | Editor de Apresentações')]:
            process=subprocess.Popen([str(INSTALL/executable)],cwd=INSTALL,
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
    sentinels={'conversation-history.json':'{"installer-test":"preserve"}\n','Setmain.cfg':'installer-test-preserve\n'}
    for name,text in sentinels.items():(INSTALL/name).write_text(text,encoding='utf-8')
    catalog_path=INSTALL/'AVATARES/movimentos.json'
    catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
    catalog['movements'].append({'id':'instalador_preservar','tag':'gesto personalizado do usuario','title':'Movimento do usuario','mode':'pose','clip':'idle'})
    catalog_text=json.dumps(catalog,ensure_ascii=False,indent=2)+'\n';catalog_path.write_text(catalog_text,encoding='utf-8')
    run(args)
    assert catalog_path.read_text(encoding='utf-8')==catalog_text,'Reinstall overwrote custom JSON movements'
    for name,text in sentinels.items():assert (INSTALL/name).read_text(encoding='utf-8')==text,name
    assert registry_state()==before
    REPORT.append('PASS: reinstall preserved user configuration/history, custom shared JSON movements and application registration')

    uninstallers=list(INSTALL.glob('unins*.exe'))
    assert len(uninstallers)==1 and uninstallers[0].resolve().is_relative_to(TEST.resolve())
    run([uninstallers[0],'/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',f'/LOG={TEST / "uninstall.log"}'])
    deadline=time.monotonic()+15
    while (INSTALL/'assistente.exe').exists() and time.monotonic()<deadline:time.sleep(.2)
    for record in manifest['files']:
        if record['path']!='AVATARES/movimentos.json':assert not (INSTALL/record['path']).exists(),record['path']
    assert catalog_path.read_text(encoding='utf-8')==catalog_text,'Uninstall deleted custom movements'
    for name,text in sentinels.items():assert (INSTALL/name).read_text(encoding='utf-8')==text,name
    assert registry_state()==before
    REPORT.append('PASS: uninstaller removed application binaries, preserved user files and JSON movements, and did not change registration')
    result={'version':OPTIONS.version,'installer_sha256':manifest['installer']['sha256'],'result':'PASS',
            'payload_files':len(manifest['files']),'profiles':11,'checks':REPORT}
    path=ROOT/f'bin/setup_assistente_{OPTIONS.build_code}.validacao.json'
    path.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('\n'.join(REPORT));print(f'Validation report: {path}')

if __name__=='__main__':main()
