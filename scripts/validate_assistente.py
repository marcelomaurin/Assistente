"""Run offline Windows validation against freshly compiled Assistente programs.
Build first with build_presentations.py and --target tests in the same directory.
Reports preserve command, exit status, duration and full per-test logs.
"""
from pathlib import Path
import argparse, datetime, hashlib, json, os, subprocess, sys, time

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build',type=Path,required=True)
    parser.add_argument('--only',nargs='+',help='Repeat named cases and update their prior results')
    parser.add_argument('--native',action='store_true',help='Also open automatic Windows/OpenGL tests')
    parser.add_argument('--all-movements',action='store_true',help='Validate 53 movements on all bundled avatars')
    args=parser.parse_args();build=args.build.resolve();reports=build/'validation-report';reports.mkdir(exist_ok=True)
    results=[]
    if args.only and (reports/'result.json').exists():
        results=json.loads((reports/'result.json').read_text(encoding='utf-8'))['cases']
    def run(name,command,timeout=180):
        if args.only and name not in args.only:return
        results[:]=[r for r in results if r['name']!=name]
        started=time.monotonic();env=dict(os.environ,ASSISTENTE_MOVEMENTS_FILE=str(ROOT/'AVATARES/movimentos.json'),ASSISTENTE_CONFIG_DIR=str(reports/'isolated-config'/name))
        if name=='motion-editor-smoke':(build/'motion-editor-smoke-result.txt').unlink(missing_ok=True)
        try:
            process=subprocess.run(list(map(str,command)),cwd=ROOT,env=env,capture_output=True,timeout=timeout)
            output=(process.stdout+process.stderr).decode('utf-8',errors='replace');status=process.returncode
            if name=='motion-editor-smoke':
                report=build/'motion-editor-smoke-result.txt'
                if report.exists():output+=report.read_text(encoding='utf-8')
                if not output.startswith('PASS:'):status=1
        except subprocess.TimeoutExpired as error:
            output=((error.stdout or b'')+(error.stderr or b'')).decode('utf-8',errors='replace')+'\nTIMEOUT';status=-1
        (reports/(name+'.log')).write_text(output,encoding='utf-8')
        results.append(dict(name=name,command=list(map(str,command)),passed=status==0,exit_code=status,seconds=round(time.monotonic()-started,2)))
        print(('PASS' if status==0 else 'FAIL'),name,flush=True)
        if status:print(output[-1500:],flush=True)
        (reports/'result.json').write_text(json.dumps({'passed':all(r['passed'] for r in results),'cases':results},ensure_ascii=False,indent=2),encoding='utf-8')
    def exe(name,*values,timeout=180):run(name,[build/(name+'.exe'),*values],timeout)
    def py(name,*values,timeout=180):run(name,[sys.executable,ROOT/'tests'/(name+'.py'),*values],timeout)
    for name in ['check_docs','check_avatar_assets','check_avatar_body','check_avatar_motion','check_avatar_gestures','check_ze_gotinha']:py(name)
    for name in ['professor_commands_tests','professor_speech_commands_tests','professor_state_tests','remote_stt_tests']:exe(name)
    exe('professor_catalog_tests',reports/'avatar-catalog')
    exe('movement_catalog_tests',reports/'catalog')
    exe('movement_animation_tests',reports/'external-animation')
    exe('movement_timeline_tests',reports/'timeline')
    exe('professor_movement_sequence_tests',reports/'sequence.json')
    exe('presentation_youtube_tests',reports/'youtube')
    py('run_presentation_checks',build/'pva_tool.exe')
    py('run_wave_finalize_checks',build/'wave_finalize_tests.exe')
    py('run_audio_path_checks',build/'audio_path_tests.exe')
    model=ROOT/'AVATARES/professor/modelo.gltf'
    for profile in sorted((ROOT/'AVATARES').glob('*/modelo.gltf')):
        run('model-'+profile.parent.name,[build/'professor_model_tests.exe',profile])
    py('run_remote_speech_checks',build/'professor_remote_speech_tests.exe',*([build/'professor_audio_smoke.exe'] if args.native else []),timeout=180)
    if args.native:
        exe('external_movement_view_tests',reports/'external-view',model)
        exe('professor_gesture_tests',model)
        exe('movement_scene_tests',model,ROOT/'AVATARES/colisoes.json')
        for profile in ['professor','ze_gotinha']:
            run('native-movements-'+profile,[build/'movement_native_completion.exe',ROOT/'AVATARES'/profile/'modelo.gltf'],timeout=100)
        exe('modern_ui_tests',reports/'catalog',model)
        exe('assistant_layout_tests',reports/'assistant-layout')
        exe('presentation_youtube_editor_tests',reports/'youtube-editor')
        exe('presentation_webview_tests')
        run('motion-editor-smoke',[build/'motion_editor.exe','--smoke-test'],timeout=120)
        py('run_presentation_native',build,model,'--without-office',timeout=240)
    py('run_presentation_flow',build,*(['--model',model] if args.native else []),timeout=180)
    py('run_presentation_rag',build,*(['--model',model,'--without-office'] if args.native else []),timeout=180)
    if args.all_movements:
        py('run_movement_completion','--probe',build/'movement_completion_probe.exe','--out',reports/'movement-completion',timeout=1200)
    binaries={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in build.glob('*.exe')}
    changed=subprocess.check_output(['git','ls-files','-m','-o','--exclude-standard','-z'],cwd=ROOT).decode('utf-8').split('\0')
    source_hashes={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in sorted(set(changed)) if name and Path(name).suffix in ['.pas','.lpr','.py','.ps1'] and (ROOT/name).is_file()}
    resource_hashes={str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in [ROOT/'AVATARES/movimentos.json',ROOT/'AVATARES/colisoes.json',*sorted((ROOT/'AVATARES/movimentos').glob('*.json'))]}
    summary={'validated_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_sha256':source_hashes,'resource_sha256':resource_hashes,'passed':all(r['passed'] for r in results),'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip()),'platform':'i386-win32','binary_sha256':binaries,'native':args.native,'all_movements':args.all_movements,'limitations':['Physical microphone/STT, Kinect, camera, real AI providers and Office not exercised','Motion editor remains a preview: no IK, undo/redo, key deletion or catalog tag editing'],'cases':results}
    (reports/'result.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print(sum(r['passed'] for r in results),'/',len(results),'passed; report:',reports/'result.json',flush=True)
    return 0 if summary['passed'] else 1

if __name__=='__main__':raise SystemExit(main())
