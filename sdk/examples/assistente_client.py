"""Python 3 client: authenticated TCP or Windows C ABI DLL. No automatic retries."""
import argparse,ctypes,json,os,socket
from pathlib import Path
BUFFER_BYTES=1048577

class AssistenteClient:
    def __init__(self,token,host='127.0.0.1',port=18766,dll=None):
        self.token=token;self.host=host;self.port=port;self.library=None
        if dll:
            self.library=ctypes.CDLL(str(Path(dll).resolve()))
            self.library.AssistenteApiVersion.restype=ctypes.c_uint32
            if self.library.AssistenteApiVersion()!=0x00010000:raise RuntimeError('Incompatible DLL ABI')
            self.api=self.library.AssistenteRequestV1
            self.api.argtypes=[ctypes.c_char_p,ctypes.c_uint16,ctypes.c_char_p,ctypes.c_char_p,ctypes.c_void_p,ctypes.c_uint32,ctypes.POINTER(ctypes.c_uint32)]
            self.api.restype=ctypes.c_int32

    def request(self,action,**fields):
        request=dict(fields,v=1,action=action)
        if 'token' in fields:raise ValueError('Pass token to the client constructor only')
        if self.library:
            buffer=ctypes.create_string_buffer(BUFFER_BYTES);required=ctypes.c_uint32()
            result=self.api(self.host.encode('ascii'),self.port,self.token.encode('ascii'),json.dumps(request,ensure_ascii=False).encode('utf-8'),buffer,len(buffer),ctypes.byref(required))
            if result:raise RuntimeError(f'DLL returned {result}; outcome may be unknown; do not automatically retry')
            response=json.loads(buffer.value)
        else:
            request['token']=self.token
            data=(json.dumps(request,ensure_ascii=False)+'\n').encode('utf-8')
            if len(data)-1>16384:raise ValueError('Request exceeds 16384 bytes')
            with socket.create_connection((self.host,self.port),timeout=3) as sock:
                sock.settimeout(15);sock.sendall(data)
                with sock.makefile('rb') as stream:reply=stream.readline(BUFFER_BYTES+1)
                if not reply.endswith(b'\n') or len(reply)>BUFFER_BYTES:raise RuntimeError('Invalid response frame')
                response=json.loads(reply.decode('utf-8'))
        if response.get('v')!=1 or type(response.get('ok')) is not bool:raise RuntimeError('Invalid response envelope')
        return response

def main():
    p=argparse.ArgumentParser(description='Assistente integration example; token from ASSISTENTE_TOKEN')
    p.add_argument('action',choices=['status','avatars','ask','get_job','speak','avatar','select_avatar','cancel'])
    p.add_argument('--host',default='127.0.0.1');p.add_argument('--port',type=int,default=18766)
    p.add_argument('--dll');p.add_argument('--text');p.add_argument('--id');p.add_argument('--command')
    a=p.parse_args();token=os.environ.get('ASSISTENTE_TOKEN')
    if not token:p.error('Set ASSISTENTE_TOKEN using the token shown by Assistente settings')
    fields={k:getattr(a,k) for k in ['text','id','command'] if getattr(a,k) is not None}
    response=AssistenteClient(token,a.host,a.port,a.dll).request(a.action,**fields)
    print(json.dumps(response,ensure_ascii=False,indent=2))
    return 0 if response['ok'] else 1
if __name__=='__main__':raise SystemExit(main())
