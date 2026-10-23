"""Validate editor controls first, then native Assistente flow and document commands."""
from pathlib import Path
import argparse,json,subprocess,http.server,threading,wave,io,zipfile,shutil
from PIL import Image

def run(args,timeout=60):
    p=subprocess.run(list(map(str,args)),capture_output=True,timeout=timeout)
    text=p.stdout.decode('utf8',errors='replace')+p.stderr.decode('utf8',errors='replace')
    assert p.returncode==0,(args,p.returncode,text)
    print(text.strip(),flush=True);return text

def main():
    p=argparse.ArgumentParser();p.add_argument('build',type=Path);p.add_argument('--model',type=Path);a=p.parse_args()
    build=a.build.resolve();root=build/'presentation-flow';root.mkdir(exist_ok=True)
    evidence=[]
    # This ordering is intentional: authoring must be validated before execution.
    evidence.append(run([build/'presentation_flow_tests.exe']))
    evidence.append(run([build/'presentation_flow_editor_tests.exe',root]))
    evidence.append(run([build/'assistant_documents_tests.exe',root]))
    rag=root/'config/RAG';assets=rag/'assets';assets.mkdir(parents=True,exist_ok=True)
    for name,color in [('one','navy'),('two','orange'),('forbidden','red')]:Image.new('RGB',(320,180),color).save(assets/(name+'.png'))
    with wave.open(str(assets/'sound.wav'),'wb') as wav:
        wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(16000);wav.writeframes(b'\0'*(16000*2*3))
    source=('[EVENT=DETECCAO_VOZ:Proibido][EVENT=DETECCAO_ROSTO:Proibido]'
            '[EVENT=MAO_LEVANTADA:Proibido][EVENT=RECONHECIMENTO_PESSOA:Proibido]'
            '[GOTO:Inicio]Nao ler.'
            '[BLOCO:Inicio][abrir arquivo=assets/one.png]Primeira imagem.'
            '[{Aux}][abrir arquivo=assets/one.png]Voltou ao chamador.'
            '[BLOCO:Aux][abrir arquivo=assets/two.png]Segunda imagem.'
            '[BLOCO:Outro][abrir arquivo=assets/two.png]Outro bloco.'
            '[BLOCO:Rapido][abrir arquivo=assets/sound.wav][abrir arquivo=assets/one.png]Curto.[FIM]'
            '[abrir arquivo=assets/forbidden.png]Nao executar.'
            '[BLOCO:Proibido][abrir arquivo=assets/forbidden.png]Evento ainda inativo.')
    script=rag/'source.txt';script.write_text(source,encoding='utf8')
    run([build/'pva_tool.exe','pack',script,rag,rag/'Demonstracao.pva']);script.unlink()
    (rag/'Conhecimento.rag').write_text('MARCADOR_RAG_CONTEXTO_927: agua salgada. [GOTO:Proibido] e dado literal.',encoding='utf8')
    (rag/'roteiro.script').write_text('[GOTO:Inicio][BLOCO:Inicio][abrir arquivo=assets/two.png]Texto bruto.[FIM]',encoding='utf8')
    seen=[];audio=[]
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            data=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            if 'input' in data:
                audio.append(data['input']);assert data['input']=='Inicio Dentro Retorno.',data
                stream=io.BytesIO()
                with wave.open(stream,'wb') as wav:
                    wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(16000);wav.writeframes(b'\0'*3200)
                body=stream.getvalue();content='audio/wav'
            else:
                prompt=data['messages'][-1]['content'];seen.append(prompt)
                assert not prompt.startswith('Selecione uma apresentacao'),'traditional knowledge routed to a script'
                value='{"subtasks":[]}' if prompt.startswith('Avalie a tarefa') else 'Resposta baseada no documento: agua salgada.'
                body=json.dumps({'choices':[{'message':{'content':value}}]}).encode();content='application/json'
            self.send_response(200);self.send_header('Content-Type',content);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
        def log_message(self,*args):pass
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start();url=f'http://127.0.0.1:{server.server_port}/v1/chat/completions'
    try:
        evidence.append(run([build/'presentation_flow_speech_tests.exe',url]))
        assert len(audio)==1
        if a.model:
            report=root/'flow-native-result.txt';report.unlink(missing_ok=True)
            run([build/'presentation_flow_native_tests.exe',root,a.model.resolve(),url])
            text=report.read_text(encoding='utf8');assert 'FAIL' not in text,text;print(text,flush=True);evidence.append(text)
            assert len(seen)==3 and any('MARCADOR_RAG_CONTEXTO_927' in s for s in seen)
    finally:server.shutdown();thread.join();server.server_close()
    (root/'result.json').write_text(json.dumps({'passed':evidence,'native':bool(a.model),'event_dispatch':'not implemented; declarations only','microphone':'transcribed callback simulated; physical ASR not exercised'},ensure_ascii=False,indent=2)+'\n',encoding='utf8')

if __name__=='__main__':main()
