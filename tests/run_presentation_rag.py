"""Validate RAG publication, indexing, routing with a local provider and native playback."""
from pathlib import Path
import argparse,json,subprocess,http.server,threading,time,os,shutil

def run(args,timeout=70):
    result=subprocess.run(list(map(str,args)),capture_output=True,timeout=timeout)
    output=result.stdout.decode('utf8',errors='replace')+result.stderr.decode('utf8',errors='replace')
    assert result.returncode==0,(args,result.returncode,output)
    print(output.strip(),flush=True)
    return output

def main():
    p=argparse.ArgumentParser();p.add_argument('build',type=Path);p.add_argument('--model',type=Path);p.add_argument('--without-office',action='store_true');a=p.parse_args()
    build=a.build.resolve();root=build/'presentation-rag';root.mkdir(exist_ok=True)
    # A fresh isolated config prevents a previous run from changing catalog ids.
    for name in ['config','agent-config']:
        directory=root/name
        if directory.exists():
            assert directory.resolve().is_relative_to(root)
            shutil.rmtree(directory)
    source=root/'energia solar.txt'
    source.write_text('[avatar=professor][voz=nova][sorriso]Energia solar: geração elétrica limpa.\n',encoding='utf8')
    run([build/'pva_tool.exe','pack',source,root,root/'energia solar.pva'])
    source=root/'oceano.txt';source.write_text('Oceanos e vida marinha.',encoding='utf8')
    run([build/'pva_tool.exe','pack',source,root,root/'oceano.pva'])
    evidence=[run([build/'presentation_rag_tests.exe',root])]
    seen=[]
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            prompt=body['messages'][-1]['content'];mode=self.path.split('/')[1];seen.append((mode,prompt))
            if prompt.startswith('Selecione uma apresentacao'):
                data=json.loads(prompt.split('Dados em JSON: ',1)[1])
                assert data['user_request']
                assert data['documents'] and all('text' in d for d in data['documents'])
                if mode in ['selected','gui']:
                    wanted='main.res' if mode=='gui' else 'energia solar.res'
                    doc=next(d for d in data['documents'] if d['document']==wanted)
                    value=json.dumps({'presentation':doc['id']})
                elif mode in ['none','fenced-none','fenced-selected']:value='{"presentation":null}'
                elif mode=='invalid':value='{"presentation":"../../outside.pva"}'
                elif mode=='cancel':time.sleep(.6);value='{"presentation":"1"}'
                else:raise AssertionError(mode)
            elif prompt.startswith('Avalie a tarefa'):value='{"subtasks":[]}'
            else:value='Resposta comum com acentuação.'
            if mode.startswith('fenced-') and prompt.startswith('Selecione uma apresentacao'):
                if mode=='fenced-selected':value='{"presentation":"1"}'
                value='\n```json\n'+value+'\n```\n'
            result=json.dumps({'choices':[{'message':{'content':value}}]},ensure_ascii=False).encode()
            try:
                self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(result)));self.end_headers();self.wfile.write(result)
            except (BrokenPipeError,ConnectionResetError):pass
        def log_message(self,*args):pass
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    base=f'http://127.0.0.1:{server.server_port}'
    try:
        for mode in ['selected','none','fenced-none','fenced-selected','invalid','cancel']:
            evidence.append(run([build/'presentation_rag_agent_tests.exe',root,base+'/'+mode,mode.removeprefix('fenced-'),base+'/none']))
        assert len([p for m,p in seen if m=='selected'])==1,'selected package entered normal synthesis/planner'
        if a.model:
            native=build/'presentation-native'
            assert (native/'main.pva').exists(),'Run run_presentation_native.py first to create fixtures'
            report=native/'rag-result.txt';report.unlink(missing_ok=True)
            run([build/'presentation_native_smoke.exe',native,'rag',a.model.resolve(),('without-office' if a.without_office else 'with-office'),base+'/gui'])
            text=report.read_text(encoding='utf8');assert 'FAIL' not in text,text;print(text.strip(),flush=True);evidence.append(text)
            assert len([p for m,p in seen if m=='gui'])==1
    finally:server.shutdown();thread.join();server.server_close()
    (root/'result.json').write_text(json.dumps({'passed':evidence,'provider':'local HTTP mock','native_playback':bool(a.model)},ensure_ascii=False,indent=2)+'\n',encoding='utf8')

if __name__=='__main__':main()
