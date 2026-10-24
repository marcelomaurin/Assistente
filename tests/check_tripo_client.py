"""Tripo3D client against a local mock of the v3 API: presigned upload,
image-to-model, rig check, rig, polling and model download, then the GLB
import. Also checks that the API key is sent only as a Bearer header and
never appears in the avatar folder. No network or real key needed."""
import json, os, shutil, sys, tempfile, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools')); sys.path.insert(0, str(ROOT / 'tests'))
KEY = 'tsk_teste_123'
STATE = {'calls': [], 'uploaded': b''}


def make_glb(path):
    import glb_import as gi, check_glb_import as cg
    tmp = Path(tempfile.mkdtemp()); (tmp / 'AVATARES').mkdir()
    g, ref = gi.reference_avatar('ref_tripo', 'Ref', True, tmp / 'AVATARES')
    P = ref.world(ref.p); body = ref.faces[ref.groups == 'body'][:, :, 0]; used = np.unique(body)
    remap = -np.ones(len(P), int); remap[used] = np.arange(len(used))
    cg.write_glb(path, P[used], remap[body]); shutil.rmtree(tmp, ignore_errors=True)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, data, code=200):
        body = json.dumps({'code': 0, 'data': data}).encode()
        self.send_response(code); self.send_header('Content-Type', 'application/json'); self.end_headers(); self.wfile.write(body)

    def _auth(self):
        if self.headers.get('Authorization') != 'Bearer ' + KEY:
            self.send_response(401); self.end_headers(); return False
        return True

    def do_POST(self):
        STATE['calls'].append(('POST', self.path))
        n = int(self.headers.get('Content-Length', 0)); body = json.loads(self.rfile.read(n) or b'{}')
        if not self._auth():
            return
        port = self.server.server_address[1]
        if self.path == '/v3/files/presign':
            assert body['format'] in ('png', 'jpg')
            return self._json({'presigned_url': f'http://127.0.0.1:{port}/upload/x', 'file_token': 'file_1', 'expires_in': 1800})
        if self.path == '/v3/generation/image-to-model':
            assert body['input'] == 'file_1'
            return self._json({'task_id': 'task_model'})
        if self.path == '/v3/animations/rig-check':
            return self._json({'riggable': True, 'rig_type': 'biped'})
        if self.path == '/v3/animations/rig':
            assert body == {'input': 'task_model', 'rig_type': 'biped', 'spec': 'mixamo'}
            return self._json({'task_id': 'task_rig'})
        self.send_response(404); self.end_headers()

    def do_PUT(self):
        STATE['calls'].append(('PUT', self.path))
        assert 'Authorization' not in self.headers, 'key leaked to the storage upload'
        STATE['uploaded'] = self.rfile.read(int(self.headers['Content-Length']))
        self.send_response(200); self.end_headers()

    def do_GET(self):
        STATE['calls'].append(('GET', self.path))
        port = self.server.server_address[1]
        if self.path.startswith('/v3/tasks/'):
            if not self._auth():
                return
            task = self.path.rsplit('/', 1)[1]
            seen = sum(1 for c in STATE['calls'] if c[1] == self.path)
            if seen < 2:
                return self._json({'task_id': task, 'status': 'running', 'progress': 50})
            return self._json({'task_id': task, 'status': 'success', 'progress': 100,
                               'output': {'model_url': f'http://127.0.0.1:{port}/files/{task}.glb'}})
        if self.path.startswith('/files/'):
            data = STATE['glb'].read_bytes()
            self.send_response(200); self.send_header('Content-Length', str(len(data))); self.end_headers(); self.wfile.write(data)
            return
        self.send_response(404); self.end_headers()


def main():
    tmp = Path(tempfile.mkdtemp())
    srv = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    try:
        STATE['glb'] = tmp / 'mock.glb'; make_glb(STATE['glb'])
        avatars = tmp / 'AVATARES'; avatars.mkdir()
        for f in ('movimentos.json', 'colisoes.json'):
            shutil.copy(ROOT / 'AVATARES' / f, avatars / f)
        photo = tmp / 'foto.png'
        from PIL import Image
        Image.new('RGB', (64, 64), (200, 150, 120)).save(photo)
        os.environ['TRIPO_API_BASE'] = f'http://127.0.0.1:{srv.server_address[1]}/v3'
        import importlib, tripo_client
        importlib.reload(tripo_client)
        try:
            tripo_client.Tripo('errada', log=lambda *_: None).upload(photo)
            raise AssertionError('wrong key accepted')
        except tripo_client.TripoError as e:
            assert '401' in str(e)
        folder = tripo_client.from_image(photo, 'tripo_teste', 'Tripo teste', KEY, rig=True, female=True,
                                         avatars=avatars, workdir=tmp, log=lambda *_: None)
        assert STATE['uploaded'] == photo.read_bytes()
        paths = [c[1] for c in STATE['calls']]
        for p in ('/v3/files/presign', '/v3/generation/image-to-model', '/v3/animations/rig-check', '/v3/animations/rig', '/v3/tasks/task_rig'):
            assert p in paths, p
        assert (folder / 'modelo.gltf').is_file()
        for f in folder.rglob('*'):
            if f.is_file() and f.suffix in ('.json', '.gltf', '.ini'):
                assert KEY not in f.read_text(encoding='utf-8', errors='ignore'), 'API key written to ' + f.name
        print('PASS: Tripo3D v3 client (upload, model, rig, polling, download, import) against a local mock; key never stored')
    finally:
        srv.shutdown(); shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
