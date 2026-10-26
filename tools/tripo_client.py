"""Tripo3D (studio.tripo3d.ai) integration through the official REST API v3.

Creates a 3D character from a photo, optionally rigs it (biped, Mixamo
skeleton), downloads the GLB and imports it as an Assistente avatar.

    python tools/tripo_client.py from-image foto.png --id nome --name "Nome" [--rig] [--male] [--avatars DIR]
    python tools/tripo_client.py download TASK_ID --out modelo.glb

The API key comes from the TRIPO_API_KEY environment variable or from
--key-file (a text file with the key). It is sent only to
openapi.tripo3d.com and never written to logs or to the avatar folder.
Endpoints follow https://developers.tripo3d.com (v3): presigned upload,
/generation/image-to-model, /animations/rig and /tasks/{id}; model URLs
expire after 5 minutes, so the download happens right after success.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = os.environ.get('TRIPO_API_BASE', 'https://openapi.tripo3d.com/v3')
TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))


class TripoError(RuntimeError):
    pass


class Tripo:
    def __init__(self, key, log=print, model=None):
        if not key:
            raise TripoError('Informe a chave da API do Tripo (TRIPO_API_KEY ou --key-file).')
        self.key = key.strip()
        self.log = log
        self.model = model

    def _request(self, method, url, body=None, headers=None, raw=False, timeout=120):
        h = {'Authorization': 'Bearer ' + self.key}
        data = None
        if body is not None:
            data = json.dumps(body).encode('utf-8'); h['Content-Type'] = 'application/json'
        h.update(headers or {})
        req = urllib.request.Request(url, data=data, method=method, headers=h)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                payload = r.read()
        except urllib.error.HTTPError as e:
            detail = e.read().decode('utf-8', 'replace')[:400]
            raise TripoError(f'Tripo respondeu {e.code}: {detail}') from None
        except urllib.error.URLError as e:
            raise TripoError(f'Sem conexão com o Tripo: {e.reason}') from None
        if raw:
            return payload
        doc = json.loads(payload.decode('utf-8'))
        if doc.get('code', 0) != 0:
            raise TripoError(f"Tripo: {doc.get('message') or doc}")
        return doc.get('data', doc)

    def upload(self, path):
        path = Path(path)
        fmt = path.suffix.lower().lstrip('.').replace('jpeg', 'jpg')
        if fmt not in ('jpg', 'png', 'webp', 'bmp', 'tiff'):
            raise TripoError('A imagem deve ser JPG, PNG, WEBP, BMP ou TIFF.')
        data = self._request('POST', API + '/files/presign', {'format': fmt})
        req = urllib.request.Request(data['presigned_url'], data=path.read_bytes(), method='PUT',
                                     headers={'Content-Type': 'application/octet-stream'})
        try:
            urllib.request.urlopen(req, timeout=300).read()
        except urllib.error.URLError as e:
            raise TripoError(f'Falha ao enviar a imagem: {e}') from None
        self.log('Imagem enviada ao Tripo')
        return data['file_token']

    def image_to_model(self, token):
        body = {'input': token}
        if self.model:
            body['model'] = self.model
        return self._request('POST', API + '/generation/image-to-model', body)['task_id']

    def rig(self, task_id):
        check = self._request('POST', API + '/animations/rig-check', {'input': task_id})
        if not check.get('riggable', True):
            raise TripoError('O Tripo informou que o modelo não pode receber esqueleto.')
        return self._request('POST', API + '/animations/rig', {'input': task_id, 'rig_type': 'biped', 'spec': 'mixamo'})['task_id']

    def wait(self, task_id, timeout=1800):
        start = time.time(); last = None
        while time.time() - start < timeout:
            data = self._request('GET', f'{API}/tasks/{task_id}')
            status = data.get('status'); progress = data.get('progress')
            if (status, progress) != last:
                self.log(f'Tripo: {status} {progress if progress is not None else ""}'.strip())
                last = (status, progress)
            if status == 'success':
                return data
            if status in ('failed', 'cancelled', 'banned', 'expired'):
                raise TripoError(f'Tarefa do Tripo terminou como {status}.')
            time.sleep(2.5)
        raise TripoError('Tempo esgotado aguardando o Tripo.')

    def download(self, task, dest):
        out = task.get('output', {})
        url = out.get('model_url') or out.get('pbr_model') or out.get('model')
        if not url:
            raise TripoError('A tarefa não trouxe o endereço do modelo.')
        with urllib.request.urlopen(url, timeout=600) as r:
            Path(dest).write_bytes(r.read())
        self.log(f'Modelo baixado: {dest}')
        return Path(dest)


def read_key(key_file=None):
    if key_file:
        return Path(key_file).read_text(encoding='utf-8').strip()
    return os.environ.get('TRIPO_API_KEY', '').strip()


def from_image(image, avatar_id, name, key, rig=True, female=True, avatars=None, workdir=None, log=print, model=None):
    import glb_import
    t = Tripo(key, log, model)
    token = t.upload(image)
    task = t.image_to_model(token)
    log(f'Tarefa criada: {task}')
    done = t.wait(task)
    if rig:
        rig_task = t.rig(task)
        done = t.wait(rig_task)
    work = Path(workdir or Path(image).parent)
    glb = t.download(done, work / f'{avatar_id}_tripo.glb')
    return glb_import.import_glb(glb, avatar_id, name, 'tripo3d', female, avatars, True, log)


def main(argv=None):
    p = argparse.ArgumentParser(description='Integração com o Tripo3D')
    sub = p.add_subparsers(dest='cmd', required=True)
    f = sub.add_parser('from-image'); f.add_argument('image'); f.add_argument('--id', required=True); f.add_argument('--name', required=True)
    f.add_argument('--rig', action='store_true'); f.add_argument('--male', action='store_true'); f.add_argument('--avatars'); f.add_argument('--key-file'); f.add_argument('--model')
    d = sub.add_parser('download'); d.add_argument('task'); d.add_argument('--out', required=True); d.add_argument('--key-file')
    a = p.parse_args(argv)
    try:
        if a.cmd == 'from-image':
            from_image(a.image, a.id, a.name, read_key(a.key_file), a.rig, not a.male, a.avatars, model=a.model)
        else:
            t = Tripo(read_key(a.key_file))
            t.download(t.wait(a.task), a.out)
    except TripoError as e:
        print('ERRO', e, file=sys.stderr)
        sys.exit(2)


if __name__ == '__main__':
    main()
