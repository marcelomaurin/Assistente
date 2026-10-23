"""Exercise the vendored TTS and Windows playback against a local silent fixture.

Build professor_remote_speech_tests and optionally professor_audio_smoke first.
No paid provider, real key, microphone or camera is used. Audio output is required.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread, Lock
import io
import json
import os
import struct
import subprocess
import sys
import tempfile
import wave


def silent_wav():
    stream = io.BytesIO()
    with wave.open(stream, 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(16000)
        wav.writeframes(b'\0' * 16000)  # 500 ms silence
    data = stream.getvalue()
    # Valid metadata makes a size/byte-rate duration estimate over four seconds.
    junk = b'JUNK' + struct.pack('<I', 128000) + b'\0' * 128000
    data = data[:36] + junk + data[36:]
    return data[:4] + struct.pack('<I', len(data) - 8) + data[8:]


def main():
    requests = []
    lock = Lock()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            text = body['input']
            with lock:
                requests.append(body)
            import time
            time.sleep(0.3)  # Observable preparation before the audible segment.
            status = 400 if text == 'fail' else 200
            payload = b'fixture failure' if status == 400 else silent_wav()
            if text == 'streaming-wav':
                payload=bytearray(payload);struct.pack_into('<I',payload,4,0xffffffff)
                offset=payload.index(b'data',36);struct.pack_into('<I',payload,offset+4,0xffffffff);payload=bytes(payload)
            if text == 'invalid-audio':
                payload = b'not a wave file'
            self.send_response(status)
            self.send_header('Content-Type', 'audio/wav')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        endpoint = f'http://127.0.0.1:{server.server_port}/v1/audio/speech'
        for filename in sys.argv[1:]:
            executable = Path(filename).resolve()
            with tempfile.TemporaryDirectory(prefix='assistente-audio-') as appdata:
                env = dict(os.environ, ASSISTENTE_CONFIG_DIR=appdata)
                result = subprocess.run([str(executable), endpoint], cwd=executable.parent,
                                        env=env, capture_output=True, timeout=45)
                print(result.stdout.decode('utf-8', errors='replace'), end='')
                print(result.stderr.decode('utf-8', errors='replace'), end='')
                if result.returncode:
                    raise RuntimeError(f'{executable.name} failed ({result.returncode})')
                assert (Path(appdata) / 'reception').is_dir(), 'Audio data isolation was not used'
                leftovers = list(Path(appdata).rglob('speech-*.wav'))
                assert not leftovers, f'Leaked temporary speech files: {leftovers}'
        assert any(r['input']=='streaming-wav' for r in requests), 'Missing real OpenAI WAV header regression'
        assert requests, 'No synthesis request reached the mock'
        assert all('[' not in r['input'] and r['response_format'] == 'wav' for r in requests)
        assert sum(r['input'] == 'primeira' for r in requests) >= 2, 'Repeated text skipped remote synthesis'
        print(f'PASS: {len(requests)} local TTS requests, clean text, WAV format, no temporary audio leaks')
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit('Usage: run_remote_speech_checks.py executable [executable...]')
    main()
