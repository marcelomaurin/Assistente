"""Exercise the integrated Windows application using isolated data and loopback mocks."""
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import subprocess
import sys
import threading
import time

build = Path(sys.argv[1]).resolve()
root = build / 'branch-integration'
root.mkdir(parents=True, exist_ok=True)


def run(name, args=(), marker='PASS:', extra_env=None):
    env = os.environ.copy()
    env['ASSISTENTE_CONFIG_DIR'] = str(root / (name + '-config'))
    if extra_env:
        env.update(extra_env)
    result = subprocess.run([str(build / (name + '.exe')), *map(str, args)],
                            env=env, capture_output=True, timeout=110)
    output = (result.stdout + result.stderr).decode('utf-8', errors='replace')
    if name == 'reception_tests':
        report = build / 'test-output' / 'results.txt'
        if report.exists():
            output += '\n' + report.read_text(encoding='utf-8', errors='replace')
    (build / (name + '-result.log')).write_text(output, encoding='utf-8')
    print(output, flush=True)
    assert result.returncode == 0 and marker in output, (name, result.returncode, output)


for name in ['assistant_config_tests', 'voice_native_tests', 'chrome_speech_tests', 'presentation_flow_tests']:
    work = root / name
    work.mkdir(exist_ok=True)
    run(name, [work])


class Provider(BaseHTTPRequestHandler):
    grounded_calls = 0

    def log_message(self, *args):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        prompt = json.dumps(body, ensure_ascii=False)
        if 'slow' in prompt:
            time.sleep(0.3)
        if 'DOCUMENTOS DE REFERENCIA' in prompt:
            assert 'laboratorio.txt' in prompt and 'agendamento' in prompt
            Provider.grounded_calls += 1
            answer = 'O laboratório de microscopia atende por agendamento. [laboratorio.txt]'
        else:
            answer = json.dumps({'action': 'responder', 'parameters': {} if 'invalid' in prompt else {
                'text': 'O microscópio produz imagens para o projeto.',
                'emotion': 'happy', 'gesture': 'explain'}, 'rationale': ''}, ensure_ascii=False)
        payload = json.dumps({'choices': [{'message': {'content': answer}}]}, ensure_ascii=False).encode()
        try:
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass


server = ThreadingHTTPServer(('127.0.0.1', 0), Provider)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
url = f'http://127.0.0.1:{server.server_port}/v1/chat/completions'
env = {'ASSISTENTE_TEST_URL': url, 'RECEPTION_TEST_URL': url}
try:
    run('vision_check', marker='PASS')
    run('reception_tests', marker='ALL TESTS PASSED', extra_env=env)
    run('app_checks', marker='ALL APP CHECKS PASSED', extra_env=env)
    assert Provider.grounded_calls == 1, ('expected one grounded call per turn', Provider.grounded_calls)
finally:
    server.shutdown()
    thread.join()
    server.server_close()

script = Path(__file__).with_name('run_presentation_rag.py')
result = subprocess.run([sys.executable, str(script), str(build)], capture_output=True, timeout=180)
output = (result.stdout + result.stderr).decode('utf-8', errors='replace')
(build / 'presentation-rag-integration-result.log').write_text(output, encoding='utf-8')
print(output, flush=True)
assert result.returncode == 0, output
print('PASS: integrated settings, PCM voice, Chrome bridge, flow, device selection, reception, single grounded call and presentation RAG', flush=True)
