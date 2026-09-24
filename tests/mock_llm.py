"""Local deterministic provider: never calls a paid service or uses real keys."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import time


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        prompt = json.dumps(body, ensure_ascii=False)
        if 'slow' in prompt:
            time.sleep(1)
        text = {'action': 'responder', 'parameters': {
            'text': 'O microscópio produz imagens para o projeto.',
            'emotion': 'happy', 'gesture': 'explain'}, 'rationale': ''}
        if 'invalid' in prompt:
            text['parameters'] = {}
        response = {'choices': [{'message': {'content': json.dumps(text, ensure_ascii=False)}}],
                    'usage': {'prompt_tokens': 100, 'completion_tokens': 20, 'total_tokens': 120}}
        payload = json.dumps(response, ensure_ascii=False).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        try:
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 18793), Handler).serve_forever()
