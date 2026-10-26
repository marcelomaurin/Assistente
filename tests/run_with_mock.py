"""Run Pascal integration checks against an ephemeral loopback-only provider."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import os
import subprocess
import threading
import time


class Handler(BaseHTTPRequestHandler):
    grounded_calls = 0

    def log_message(self, *args):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        prompt = json.dumps(body, ensure_ascii=False)
        if 'slow' in prompt:
            time.sleep(0.3)
        if 'DOCUMENTOS DE REFERENCIA' in prompt:
            assert 'laboratorio.txt' in prompt
            assert 'agendamento' in prompt
            Handler.grounded_calls += 1
            answer = 'O laboratório de microscopia atende por agendamento. [laboratorio.txt]'
        else:
            answer = json.dumps({'action': 'responder', 'parameters': {} if 'invalid' in prompt else {
                'text': 'O microscópio produz imagens para o projeto.',
                'emotion': 'happy', 'gesture': 'explain'}, 'rationale': ''}, ensure_ascii=False)
        payload = json.dumps({'choices': [{'message': {'content': answer}}],
            'usage': {'prompt_tokens': 10, 'completion_tokens': 10, 'total_tokens': 20}},
            ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        try:
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass


if __name__ == '__main__':
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    env = os.environ.copy()
    env['RECEPTION_TEST_URL'] = env['ASSISTENTE_TEST_URL'] = f'http://127.0.0.1:{server.server_port}/v1/chat/completions'
    try:
        result = subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', str(Path(__file__).with_name('run_checks.ps1'))], env=env, timeout=180,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0),
            capture_output=True, encoding='utf-8', errors='replace')
        print(result.stdout)
        if result.stderr:
            print(result.stderr)
        if result.returncode:
            raise SystemExit(result.returncode)
        assert Handler.grounded_calls == 1, 'one grounded request per reception turn'
        print('PASS one grounded request per turn; no external API used')
    finally:
        server.shutdown()
        server.server_close()
