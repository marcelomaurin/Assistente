"""Real Release GUI + API, isolated settings, local mock LLM; no paid service."""
import ctypes
from ctypes import wintypes
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json,os,socket,subprocess,threading,time,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
TOKEN='c3'*32
REPORT=[]

class Handler(BaseHTTPRequestHandler):
    calls=0
    def log_message(self,*args):pass
    def do_POST(self):
        body=self.rfile.read(int(self.headers['Content-Length'])).decode()
        type(self).calls+=1
        if 'slow-check' in body:time.sleep(1)
        text='{"subtasks":[]}' if 'Avalie a tarefa abaixo' in body else 'Olá! Integração verificada com provedor local.'
        data=json.dumps({'choices':[{'message':{'content':text}}],'usage':{'prompt_tokens':1,'completion_tokens':1,'total_tokens':2}},ensure_ascii=False).encode()
        self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Content-Length',str(len(data)));self.end_headers()
        try:self.wfile.write(data)
        except OSError:pass

def port():
    with socket.socket() as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]

def call(p,action='status',token=TOKEN,**kw):
    with socket.create_connection(('127.0.0.1',p),timeout=3) as s:
        s.settimeout(15);s.sendall((json.dumps(dict(v=1,token=token,action=action,**kw),ensure_ascii=False)+'\n').encode())
        return json.loads(s.makefile('rb').readline(1048577))

def wait_job(p,identifier):
    deadline=time.monotonic()+25
    while time.monotonic()<deadline:
        job=call(p,'get_job',id=identifier)['result']
        if job['state']!='running':return job
        time.sleep(.15)
    raise AssertionError('Job never completed')

def close(process):
    u=ctypes.WinDLL('user32');callback=ctypes.WINFUNCTYPE(wintypes.BOOL,wintypes.HWND,wintypes.LPARAM)
    u.EnumWindows.argtypes=[callback,wintypes.LPARAM];u.GetWindowThreadProcessId.argtypes=[wintypes.HWND,ctypes.POINTER(wintypes.DWORD)]
    u.PostMessageW.argtypes=[wintypes.HWND,wintypes.UINT,wintypes.WPARAM,wintypes.LPARAM]
    @callback
    def visit(hwnd,_):
        pid=wintypes.DWORD();u.GetWindowThreadProcessId(hwnd,ctypes.byref(pid))
        if pid.value==process.pid:u.PostMessageW(hwnd,0x10,0,0)
        return True
    u.EnumWindows(visit,0)
    assert process.wait(timeout=15)==0,'GUI shutdown failed'

def main():
    test=ROOT/'build/integration'/('host-'+str(uuid.uuid4()));test.mkdir(parents=True)
    mock=ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=mock.serve_forever,daemon=True).start()
    apiport=port()
    cfg=test/'Setmain.cfg'
    cfg.write_text(f'CONTINUOUS_LISTENING:0\nAUTOSPEAK:0\nVISION_SOURCE:none\nAVATAR3D_PROFILE:professor\nCHATGPTPROVIDER:7\nCHATGPTMODEL:fixture\nCHATGPT:fake-local-key\nCHATGPTURL:http://127.0.0.1:{mock.server_port}/v1/chat/completions\nJARVISURL:\nINTEGRATION_ENABLED:1\nINTEGRATION_BIND:127.0.0.1\nINTEGRATION_PORT:{apiport}\nINTEGRATION_TOKEN:{TOKEN}\nINTEGRATION_ALLOWED_IPS:127.0.0.1\n',encoding='utf-8')
    exe=ROOT/'build/professor/assistente.exe'
    process=None
    try:
        for cycle in range(2):
            process=subprocess.Popen([str(exe)],cwd=test,env=dict(os.environ,ASSISTENTE_CONFIG_DIR=str(test)))
            deadline=time.monotonic()+35
            while True:
                try:status=call(apiport);assert status['ok'];break
                except (OSError,ValueError):
                    assert process.poll() is None,'Application terminated during startup'
                    assert time.monotonic()<deadline,'API did not start'
                    time.sleep(.25)
            assert status['result']['service']=='Assistente'
            if cycle==1:
                REPORT.append('PASS: restarted application authenticated using DPAPI-protected persisted token')
                close(process);process=None;break
            assert call(apiport,token='d4'*32)['error']=='unauthorized'
            assert call(apiport,'speak',text='Olá')['error']=='speech_disabled'
            assert call(apiport,'unknown')['error']=='unknown_action'
            assert call(apiport,'ask',text='')['error']=='invalid_text'
            assert call(apiport,'get_job',id='unknown')['error']=='not_found'
            avatars=call(apiport,'avatars')['result'];assert len(avatars)==10
            assert call(apiport,'select_avatar',id='not-a-model')['error']=='not_found'
            assert call(apiport,'select_avatar',id='engenheiro')['ok']
            assert call(apiport)['result']['profile']=='engenheiro'
            assert call(apiport,'avatar',command='wave')['ok']
            assert call(apiport,'avatar',command='invalid')['error']=='invalid_command'
            persisted=cfg.read_text(encoding='utf-8-sig')
            assert 'INTEGRATION_TOKEN:dpapi:' in persisted and TOKEN not in persisted
            REPORT.append('PASS: real GUI status, ten avatars, selection persisted, gesture accepted; invalid token/actions/text/IDs and disabled speech rejected')
            jobid=call(apiport,'ask',text='Olá, integração')['result']['id']
            job=wait_job(apiport,jobid)
            assert job['state']=='completed' and 'Integração verificada' in job['text'],job
            assert Handler.calls>=3
            assert (test/'conversation-history.json').is_file()
            REPORT.append('PASS: authenticated ask executed through existing ChatGPT agent, polled to completed with Portuguese response from local mock provider; isolated history saved')
            jobid=call(apiport,'ask',text='slow-check')['result']['id']
            assert call(apiport,'ask',text='second')['error']=='busy'
            assert call(apiport,'cancel')['ok']
            assert wait_job(apiport,jobid)['state']=='cancelled'
            REPORT.append('PASS: concurrent ask returns busy, cancellation reaches terminal cancelled state')
            close(process);process=None
            REPORT.append('PASS: actual Release application closed normally with integration active')
        (ROOT/'build/integration/host-validation.json').write_text(json.dumps(REPORT,ensure_ascii=False,indent=2),encoding='utf-8')
        print('\n'.join(REPORT))
    finally:
        if process and process.poll() is None:process.kill();process.wait()
        mock.shutdown();mock.server_close()
if __name__=='__main__':main()
