"""Build the Lazarus presentation editor, PVA CLI and updated Assistente on Windows."""
from pathlib import Path
import argparse, os, shutil, subprocess, sys, xml.etree.ElementTree as ET

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument('--base',type=Path,help='Existing project root when validating staged sources')
    p.add_argument('--out',type=Path)
    p.add_argument('--lazarus',type=Path,default=Path(r'C:\lazarus'))
    p.add_argument('--compiler',type=Path,default=Path(r'C:\FPC\3.2.2\bin\i386-Win32\fpc.exe'))
    p.add_argument('--castle',type=Path)
    p.add_argument('--release',action='store_true',help='Strip executable debug symbols for distribution')
    p.add_argument('--target',default='all',choices=['all','editor','assistant','tool','tests'])
    a=p.parse_args();root=a.root.resolve();base=(a.base or root).resolve()
    out=(a.out or base/'build/presentations').resolve();units=out/'units';units.mkdir(parents=True,exist_ok=True)
    platform='i386-win32';laz=a.lazarus
    args=[str(a.compiler),'-MObjFPC','-Scghi','-O1','-gl','-dLCL','-dLCLwin32','-dCASTLE_ENGINE_LAZARUS_PACKAGE','-FU'+str(units),'-FE'+str(out)]
    if a.release:
        args.remove('-gl');args.append('-Xs')
    paths=[root/'src',root/'vendor/chatgpt-voice',base/'src',base/'vendor/chatgpt-voice',base/'build/professor/units'/platform]
    for rel in [f'lcl/units/{platform}/win32',f'lcl/units/{platform}',f'components/lazutils/lib/{platform}',
                f'packager/units/{platform}',f'components/synedit/units/{platform}/win32',f'components/lazcontrols/lib/{platform}/win32',
                f'components/ideintf/units/{platform}/win32',f'components/buildintf/units/{platform}','components/opengl']:
        paths.append(laz/rel)
    castle=a.castle or Path(os.environ.get('CASTLE_ENGINE_PATH',str(base/'.deps/castle-engine')))
    if castle.exists():
        for package in ['castle_engine_base','castle_engine_lcl']:
            path=castle/'packages/lazarus'/f'{package}.lpk'
            tree=ET.parse(path)
            for node in tree.findall('.//SearchPaths/OtherUnitFiles')+tree.findall('.//SearchPaths/IncludeFiles'):
                for entry in node.get('Value','').split(';'):
                    d=(path.parent/entry.replace('\\','/')).resolve();paths.append(d);args.append('-Fi'+str(d))
    chat=base/'.deps/chatgpt-integration-baseline'
    if not chat.exists():chat=base.parent/'CHATGPT'
    if not chat.exists():raise RuntimeError('CHATGPT dependency absent; run scripts/prepare_chatgpt_baseline.ps1')
    paths.append(chat)
    for directory,dirs,_ in os.walk(chat/'pacote'):
        dirs[:]=[x for x in dirs if x.lower() not in ['samples','lib','backup','.git']]
        paths.append(Path(directory));args.append('-Fi'+directory)
    for d in paths:args.append('-Fu'+str(d))
    args+=['-Fi'+str(base/'src'),'-Fi'+str(base/'vendor/chatgpt-voice')]
    targets={'tool':root/'tools/pva_tool.lpr','editor':root/'src/presentation_editor.lpr',
             'assistant':root/'src/assistente.lpr'}
    if a.target=='tests':
        targets={n:base/'tests'/f'{n}.lpr' for n in ['professor_commands_tests','professor_speech_commands_tests','professor_state_tests']}
        targets.update({n:root/'tests'/f'{n}.lpr' for n in ['presentation_native_smoke','presentation_ai_tests','presentation_speech_tests','presentation_rag_tests','presentation_rag_agent_tests','presentation_flow_tests','presentation_flow_editor_tests','assistant_documents_tests','presentation_flow_native_tests','presentation_flow_speech_tests']})
    elif a.target!='all':targets={a.target:targets[a.target]}
    for name,source in targets.items():
        cmd=args+(['-WG'] if name in ['editor','assistant'] else [])+[str(source)]
        proc=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        (out/f'{name}-build.log').write_bytes(proc.stdout);print(proc.stdout.decode(errors='replace'),flush=True)
        if proc.returncode:raise SystemExit(proc.returncode)
    if 'assistant' in targets:
        shutil.copytree(base/'AVATARES',out/'AVATARES',dirs_exist_ok=True)
    if any(n in targets for n in ['assistant','editor']):
        for name in ['libeay32.dll','ssleay32.dll','libcrypto-1_1.dll','libssl-1_1.dll']:
            source=base/'src'/name
            if source.exists():shutil.copy2(source,out/name)
    print('Build:',out)
if __name__=='__main__':main()
