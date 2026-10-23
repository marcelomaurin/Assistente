"""Completed OpenAI streaming WAV headers: exact PCM/metadata preservation."""
from pathlib import Path
import ctypes
import os
import stat
import struct
import subprocess
import sys
import tempfile

def chunk(name,payload):
    return name+struct.pack('<I',len(payload))+payload+(b'\0' if len(payload)%2 else b'')

def main():
    exe=Path(sys.argv[1]).resolve()
    fmt=chunk(b'fmt ',struct.pack('<HHIIHH',1,1,24000,48000,2,16))
    pcm=bytes(range(256))*100
    body=b'WAVE'+fmt+chunk(b'JUNK',b'metadata!')+chunk(b'data',pcm)
    standard=b'RIFF'+struct.pack('<I',len(body))+body
    data_offset=12+len(fmt)+len(chunk(b'JUNK',b'metadata!'))+4
    count=0
    with tempfile.TemporaryDirectory(prefix='assistente-wav-') as tmp:
        for name,riff,data in [('finite',len(body),len(pcm)),('streaming',0xffffffff,0xffffffff),
                               ('riff-only',0xffffffff,len(pcm)),('data-only',len(body),0xffffffff),
                               ('zero-stream',0,0)]:
            before=bytearray(standard)
            struct.pack_into('<I',before,4,riff);struct.pack_into('<I',before,data_offset,data)
            file=Path(tmp)/(name+'.wav');file.write_bytes(before)
            result=subprocess.run([str(exe),str(file),'ok'],capture_output=True,timeout=10)
            assert result.returncode==0,(name,result.stdout,result.stderr)
            assert file.read_bytes()==standard,(name,'PCM, metadata, padding or header changed incorrectly')
            count+=1
        for name,bad in [('not-wave',b'not a WAV'),('truncated-data',standard[:-2]),
                          ('missing-fmt',b'RIFF'+struct.pack('<I',len(pcm)+12)+b'WAVE'+chunk(b'data',pcm)),
                          ('bad-chunk',standard[:36]+b'JUNK'+struct.pack('<I',0xffffffff)+b'xx')]:
            file=Path(tmp)/(name+'.wav');file.write_bytes(bad)
            result=subprocess.run([str(exe),str(file),'reject'],capture_output=True,timeout=10)
            assert result.returncode==0,(name,result.stdout,result.stderr)
            assert file.read_bytes()==bad,(name,'Rejected WAV was modified')
            count+=1
        file=Path(tmp)/'readonly.wav';file.write_bytes(standard);file.chmod(stat.S_IREAD)
        try:
            result=subprocess.run([str(exe),str(file),'ok'],capture_output=True,timeout=10)
            assert result.returncode==0,(result.stdout,result.stderr)
            assert file.read_bytes()==standard
        finally:file.chmod(stat.S_IWRITE|stat.S_IREAD)
        count+=1
    if len(sys.argv)>2:
        audio=Path(sys.argv[2]).resolve();before=audio.read_bytes()
        result=subprocess.run([str(exe),str(audio),'ok'],capture_output=True,timeout=10)
        assert result.returncode==0,(result.stdout,result.stderr)
        after=audio.read_bytes();offset=after.index(b'data')+4
        assert after[offset+4:]==before[offset+4:],'Real diagnostic PCM was changed'
        if os.name=='nt':
            winmm=ctypes.WinDLL('winmm')
            winmm.mciSendStringW.argtypes=[ctypes.c_wchar_p,ctypes.c_wchar_p,ctypes.c_uint,ctypes.c_void_p]
            code=winmm.mciSendStringW(f'open "{audio}" type waveaudio alias assistente_wave_check',None,0,None)
            assert code==0,('Real OpenAI WAV still rejected by MCI',code)
            try:
                value=ctypes.create_unicode_buffer(256)
                code=winmm.mciSendStringW('status assistente_wave_check length',value,256,None)
                assert code==0 and int(value.value)>0
                print('PASS: real OpenAI diagnostic WAV accepted by MCI; duration ms:',value.value)
            finally:winmm.mciSendStringW('close assistente_wave_check',None,0,None)
    print(f'PASS: {count} WAV cases; streaming sizes, exact PCM/metadata preservation, rejected truncation and read-only playback')

if __name__=='__main__':main()
