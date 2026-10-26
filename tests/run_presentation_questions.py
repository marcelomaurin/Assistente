from pathlib import Path
import subprocess,http.server,threading,json,io,wave,shutil,sys
from PIL import Image
root=Path(__file__).resolve().parents[1];build=root/'build/presentation-questions';work=build/'validation';assets=work/'assets';assets.mkdir(parents=True,exist_ok=True)
for n,c in [('one','navy'),('two','orange'),('three','green'),('detail','purple')]:Image.new('RGB',(600,300),c).save(assets/(n+'.png'))
def run(args):
 p=subprocess.run(list(map(str,args)),capture_output=True,timeout=85);text=p.stdout.decode('utf-8',errors='replace')+p.stderr.decode('utf-8',errors='replace');print(text,flush=True);assert p.returncode==0,(p.returncode,text);return text
with wave.open(str(assets/'background.wav'),'wb') as wav:
 wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(16000);wav.writeframes(b'\0'*16000*2*6)
script=('[abrir arquivo=assets/background.wav][abrir arquivo=assets/one.png]Aula.[PERGUNTAR][abrir arquivo=assets/two.png]Seguimos.[MENU]'
 '[abrir arquivo=assets/three.png]Final.[PERGUNTAR][FIM]'
 '[BLOCO:Detalhes][abrir arquivo=assets/detail.png]Detalhe.[CONTINUAR]'
 '[BLOCO:Mais perguntas][abrir arquivo=assets/detail.png][PERGUNTAR][CONTINUAR]'
 '[BLOCO:Referencia]O codigo da aula e CODIGO_AULA_927.')
script+=''.join(f'[BLOCO:Opcao {i:02d}]Conteudo adicional.' for i in range(40))
run([Path(r'C:\ffmpeg\bin\ffmpeg.exe'),'-y','-loglevel','error','-f','lavfi','-i','color=c=blue:s=320x240:r=10','-t','15','-c:v','rawvideo','-pix_fmt','bgr24',assets/'local.avi'])
for name,text in [('local-video','[abrir arquivo=assets/local.avi]'+('Video local. '*80)+'[abrir arquivo=assets/two.png][PERGUNTAR][FIM]'),('video','[youtube=https://youtu.be/M7lc1UVf-VE][abrir arquivo=assets/two.png][PERGUNTAR][FIM]'),('questions',script),('manual','[abrir arquivo=assets/one.png]'+('A explicacao da aula continua com muitos detalhes. '*80)+'[FIM]')]:
 source=work/(name+'.script');source.write_text(text,encoding='utf-8');run([build/'pva_tool.exe','pack',source,work,work/(name+'.pva')])
rag=work/'config/RAG';rag.mkdir(parents=True,exist_ok=True)
source=work/'complemento.script';source.write_text('O codigo da aula tem a referencia complementar RAG_COMPLEMENTO_731.',encoding='utf-8')
run([build/'pva_tool.exe','pack',source,work,rag/'complemento.pva'])
seen=[]
class Handler(http.server.BaseHTTPRequestHandler):
 def do_POST(self):
  data=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  if 'input' in data:
   stream=io.BytesIO()
   with wave.open(stream,'wb') as wav:
    wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(16000);wav.writeframes(b'\0'*16000*2*(3 if len(data['input'])>500 else 1))
   body=stream.getvalue();self.send_response(200);self.send_header('Content-Type','audio/wav');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body);return
  prompt=data['messages'][-1]['content'];seen.append(prompt)
  assert 'CODIGO_AULA_927' in prompt or 'explicacao da aula' in prompt,prompt
  assert not prompt.startswith('Selecione uma apresentacao'),prompt
  if not prompt.startswith('Avalie a tarefa'):assert 'RAG_COMPLEMENTO_731' in prompt and 'complemento.pva' in prompt,prompt
  value='{"subtasks":[]}' if prompt.startswith('Avalie a tarefa') else 'O codigo da aula e CODIGO_AULA_927. [CONTINUAR]'
  body=json.dumps({'choices':[{'message':{'content':value}}]}).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
 def log_message(self,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
try:
 result=[]
 for mode in (sys.argv[1:] or ['silent','speech']):
  result.append(run([build/'presentation_question_tests.exe',work,f'http://127.0.0.1:{server.server_port}/v1/chat/completions',mode]))
 assert len(seen)>=2
 (work/'result.json').write_text(json.dumps({'passed':True,'native':result,'ai_requests':len(seen),'voice':'callback de transcricao; microfone fisico nao testado'},ensure_ascii=False,indent=2),encoding='utf-8')
finally:server.shutdown();thread.join();server.server_close()
