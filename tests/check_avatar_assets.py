"""Validate all bundled profiles without network, GPU or third-party packages."""
import base64
import json
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[1]
profiles = ['professor', 'medico', 'engenheiro', 'programador', 'dona_de_casa',
            'empresario', 'padre', 'crianca', 'bebe', 'robo']
clips = {'idle', 'listening', 'thinking', 'talking', 'wave', 'walk'}
for profile in profiles:
    folder = root / 'AVATARES' / profile
    manifest = json.loads((folder / 'avatar.json').read_text(encoding='utf-8'))
    assert manifest['id'] == profile and manifest['name']
    asset = json.loads((folder / manifest['model']).read_text(encoding='utf-8'))
    assert asset['asset']['version'] == '2.0'
    assert {a['name'] for a in asset['animations']} == clips
    binary = base64.b64decode(asset['buffers'][0]['uri'].split(',')[1])
    assert len(binary) == asset['buffers'][0]['byteLength']
    for view in asset['bufferViews']:
        assert view['byteOffset'] % 4 == 0
        assert view['byteOffset'] + view['byteLength'] <= len(binary)
    for source in asset.get('images', []):
        assert (folder / source['uri']).is_file()
    for animation in asset['animations']:
        paths = [(c['target']['node'], c['target']['path']) for c in animation['channels']]
        assert len(set(paths)) == len(paths), f'duplicate animated property: {profile}'
        for sampler in animation['samplers']:
            inp, out = (asset['accessors'][sampler[k]] for k in ['input', 'output'])
            assert inp['count'] == out['count'] >= 2
            view = asset['bufferViews'][inp['bufferView']]
            times = struct.unpack_from('<' + 'f'*inp['count'], binary, view['byteOffset'])
            assert times[0] == 0 and all(a < b for a, b in zip(times, times[1:]))
    print('PASS:', profile, 'geometry, embedded buffer, six animation tracks')
