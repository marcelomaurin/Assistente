"""Real TCP + C ABI tests. Uses isolated local fixture, no AI/device/provider."""
import ctypes,importlib.util,json,os,socket,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
TOKEN='a1'*32
ENV=dict(os.environ,ASSISTENTE_INTEGRATION_TOKEN=TOKEN)
REPORT=[]
def free_port():
    with socket.socket() as sock:sock.bind(('127.0.0.1',0));return sock.getsockname()[1]
def start(allowed='127.0.0.1',port=None):
    port=port or free_port()
    p=subprocess.Popen([str(ROOT/'build/integration/integration_server_fixture.exe'),str(port),allowed],env=ENV,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    assert p.stdout.readline().strip()==b'READY','Fixture did not start'
    return p,port
def call(port,request,fragment=False):
    data=request if isinstance(request,bytes) else (json.dumps(request,ensure_ascii=False)+'\n').encode()
    with socket.create_connection(('127.0.0.1',port),timeout=4) as sock:
        sock.settimeout(15)
        if fragment:
            for b in data:sock.sendall(bytes([b]))
        else:sock.sendall(data)
        response=sock.makefile('rb').readline(1048577)
        return json.loads(response)
def request(action='echo',**kw):return dict(v=1,token=TOKEN,action=action,**kw)
def stop(p,port):
    if p.poll() is None:
        try:call(port,request('stop_fixture'))
        except (OSError,ValueError):pass
    try:assert p.wait(timeout=5)==0
    finally:
        if p.poll() is None:p.kill();p.wait()
def check(value,message):assert value,message
def main():
    p,port=start()
    try:
        for token in ['', 'bad', 'b2'*32, TOKEN[:63]]:
            check(call(port,dict(v=1,token=token,action='echo'))['error']=='unauthorized','Token bypass')
        check(call(port,dict(v=1,action='echo'))['error']=='unauthorized','Missing token accepted')
        for payload in [b'[]\n',b'{"v":2,"action":"echo"}\n',b'{"v":1,"action":"echo","token":7}\n',
                        b'{"v":1,"action":"echo","token":"'+TOKEN.encode()+b'","token":"bad"}\n',
                        b'{"v":1,"action":"echo","text":"\xff"}\n',b'{"v":1,"action":"echo","token":"'+TOKEN.encode()+b'"} trailing\n',
                        b'{"v":1,"action":"echo","nested":'+b'['*40+b'0'+b']'*40+b'}\n']:
            result=call(port,payload)
            check(not result['ok'],'Malformed input executed')
        result=call(port,request(text='Olá 世界 🎓'),True)['result']
        check(result['text']=='Olá 世界 🎓' and result['main_thread'] and result['token_removed'],'UTF-8/thread/auth boundary')
        check(result['count']==1,'Rejected requests reached callback')
        with socket.create_connection(('127.0.0.1',port)) as s:
            s.sendall(json.dumps(request(text='no delimiter')).encode());s.shutdown(socket.SHUT_WR)
            check(json.loads(s.makefile('rb').readline())['error']=='invalid_frame','EOF executed request')
        try:
            result=call(port,b'x'*17000+b'\n');check(result['error']=='invalid_frame','Oversize accepted')
        except (ConnectionResetError,ConnectionAbortedError,json.JSONDecodeError):pass
        result=call(port,request())['result'];check(result['count']==2,'Invalid frames dispatched')
        REPORT.append('PASS: absent/wrong tokens, malformed/duplicate JSON, invalid UTF-8, EOF/oversize; fragmented Unicode; main-thread delivery; token removed before handler')
        for arch in ['win32','win64']:
            dll=ROOT/f'bin/integration/{arch}/assistente_integration.dll'
            probe=ROOT/f'build/integration/{arch}/integration_dll_probe.exe'
            r=subprocess.run([str(probe),str(dll),str(port)],env=ENV,capture_output=True,timeout=25)
            check(r.returncode==0,(arch,r.returncode,r.stderr.decode(errors='replace')))
            data=json.loads(r.stdout)['result']
            check(data['text']=='Olá 世界' and data['token_removed'] and data['count']==(3 if arch=='win32' else 4),arch+' C ABI UTF-8/buffer no-send')
            REPORT.append('PASS: '+arch+' DLL loaded dynamically, cdecl exports, Unicode and caller buffer; small buffer rejected before sending')
        dll=ctypes.CDLL(str(ROOT/'bin/integration/win64/assistente_integration.dll'))
        api=dll.AssistenteRequestV1
        api.argtypes=[ctypes.c_char_p,ctypes.c_uint16,ctypes.c_char_p,ctypes.c_char_p,ctypes.c_void_p,ctypes.c_uint32,ctypes.POINTER(ctypes.c_uint32)]
        api.restype=ctypes.c_int32
        needed=ctypes.c_uint32();buffer=ctypes.create_string_buffer(1048577)
        check(api(b'127.0.0.1',port,TOKEN.encode(),b'{"v":1,"action":"echo"}',buffer,len(buffer),ctypes.byref(needed))==0,'Python ctypes')
        check(json.loads(buffer.value)['ok'],'ctypes reply')
        check(api(b'127.0.0.1',port,b'wrong',b'{"v":1,"action":"echo"}',buffer,len(buffer),ctypes.byref(needed))==3,'DLL invalid token format')
        REPORT.append('PASS: Python 64-bit ctypes interoperability')
        spec=importlib.util.spec_from_file_location('assistente_example',ROOT/'sdk/examples/assistente_client.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        for path in [None,ROOT/'bin/integration/win64/assistente_integration.dll']:
            client=module.AssistenteClient(TOKEN,port=port,dll=path)
            check(client.request('echo',text='Olá 🎓')['result']['text']=='Olá 🎓','Documented example failed')
        REPORT.append('PASS: documented Python SDK example through direct TCP and DLL, including Unicode')
        r=subprocess.run([str(ROOT/'build/integration/integration_server_fixture.exe'),str(port),'127.0.0.1'],env=ENV,capture_output=True,timeout=5)
        check(r.returncode!=0,'Port conflict silently accepted')
        check(call(port,request())['ok'],'Existing listener broken by collision')
        REPORT.append('PASS: occupied port fails without replacing active listener')
    finally:stop(p,port)
    p,port=start('192.0.2.10')
    try:
        try:
            result=call(port,request(ip='192.0.2.10',forwarded_for='192.0.2.10'))
            check(result['error']=='ip_not_allowed','IP whitelist spoofed')
        except (ConnectionResetError,ConnectionAbortedError):
            # Peer is rejected before reading the request; Windows can reset
            # a connection with unread input instead of delivering the JSON.
            check(p.poll() is None,'Listener crashed during IP rejection')
        REPORT.append('PASS: real socket peer rejected despite valid token and spoofed IP fields')
    finally:
        p.terminate();p.wait(timeout=5)
    for allowed in ['', '*', 'localhost','127.0.0.1;invalid','0.0.0.0/0']:
        r=subprocess.run([str(ROOT/'build/integration/integration_server_fixture.exe'),str(free_port()),allowed],env=ENV,capture_output=True,timeout=5)
        check(r.returncode!=0,'Invalid whitelist started listener')
    REPORT.append('PASS: empty/malformed whitelist, hostname and wildcard fail closed')
    silent_port=free_port()
    p=subprocess.Popen([str(ROOT/'build/integration/integration_server_fixture.exe'),str(silent_port),'127.0.0.1','400'],env=ENV,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    try:
        check(p.stdout.readline().strip()==b'READY','Short-lived fixture did not start')
        with socket.create_connection(('127.0.0.1',silent_port)):
            check(p.wait(timeout=5)==0,'Silent client blocked shutdown')
        REPORT.append('PASS: silent client cannot prevent bounded server shutdown')
    finally:
        if p.poll() is None:p.kill();p.wait()
    (ROOT/'build/integration/security-validation.json').write_text(json.dumps(REPORT,indent=2),encoding='utf-8')
    print('\n'.join(REPORT))
if __name__=='__main__':main()
