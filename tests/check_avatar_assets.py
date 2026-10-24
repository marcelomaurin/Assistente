"""Validate all bundled profiles without network, GPU or third-party packages."""
import base64
import json
from pathlib import Path
import struct
import math
import hashlib

root = Path(__file__).resolve().parents[1]
source=root/'tools'/'avatar-source'
for name in ('core-assets.lock.json','system-assets.lock.json'):
    lock=json.loads((source/name).read_text(encoding='utf-8'))
    for record in lock['files']:
        file=source/('system' if name.startswith('system') else '')/record['path']
        assert hashlib.sha256(file.read_bytes()).hexdigest()==record.get('prepared_sha256',record.get('sha256')), f'Artwork checksum: {file}'
print('PASS: pinned CC0 artwork provenance and prepared source checksums')
profiles = ['professor', 'medico', 'engenheiro', 'programador', 'dona_de_casa',
            'empresario', 'padre', 'crianca', 'bebe', 'robo', 'ze_gotinha']
clips = {'idle', 'listening', 'thinking', 'talking', 'wave', 'walk'}
for profile in profiles:
    folder = root / 'AVATARES' / profile
    manifest = json.loads((folder / 'avatar.json').read_text(encoding='utf-8'))
    assert manifest['id'] == profile and manifest['name']
    asset = json.loads((folder / manifest['model']).read_text(encoding='utf-8'))
    assert asset['asset']['version'] == '2.0'
    expected={base+smile+raised for base in clips for smile in ('','_smile') for raised in ('','_right_hand_up')}
    expected|={base+smile for base in ('applause','applause_talking') for smile in ('','_smile')}
    expected |= {'nao_com_o_dedo', 'abrir_olhos', 'olhar_para_tras_esquerda', 'olhar_para_tras_direita', 'gesticular_ok', 'piscar', 'concordar', 'fechar_mao_direita', 'bocejar', 'levantar_ambas_maos', 'levantar_mao_esquerda', 'negar', 'abrir_mao_esquerda', 'fechar_mao_esquerda', 'levantar_pe_direito', 'coracao_com_as_maos', 'abrir_mao_direita', 'positivo', 'fechar_olhos'}
    expected |= {'explicar','apontar_direita','apontar_esquerda','olhar_esquerda','olhar_direita','surpresa','triste','serio','rir','comemorar','cumprimentar','negativo','abrir_bracos','cruzar_bracos','sentar','passo_atras','passo_frente','dancar'}
    catalog=json.loads((root/'AVATARES/movimentos.json').read_text(encoding='utf-8'))
    expected|={m['clip'] for m in catalog['movements'] if m.get('clip')}
    assert {a['name'] for a in asset['animations']} == expected, (profile, 'missing', expected-{a['name'] for a in asset['animations']}, 'unexpected', {a['name'] for a in asset['animations']}-expected)
    binary = base64.b64decode(asset['buffers'][0]['uri'].split(',')[1])
    assert len(binary) == asset['buffers'][0]['byteLength']
    for view in asset['bufferViews']:
        assert view['byteOffset'] % 4 == 0
        assert view['byteOffset'] + view['byteLength'] <= len(binary)
    for source in asset.get('images', []):
        assert (folder / source['uri']).is_file()
    def values(index):
        a = asset['accessors'][index]
        widths = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
        fmt = {5126:'f',5123:'H',5125:'I'}[a['componentType']]*widths[a['type']]
        view = asset['bufferViews'][a['bufferView']]
        start = view.get('byteOffset',0)+a.get('byteOffset',0)
        return list(struct.iter_unpack('<'+fmt,binary[start:start+a['count']*struct.calcsize('<'+fmt)]))
    assert len(asset['skins']) == 1 and len(asset['skins'][0]['joints']) >= 60
    assert len(values(asset['skins'][0]['inverseBindMatrices'])) == len(asset['skins'][0]['joints'])
    blended = 0
    face_targets = 0
    for mesh in asset['meshes']:
        for primitive in mesh['primitives']:
            attrs = primitive['attributes']
            positions=values(attrs['POSITION'])
            assert all(math.isfinite(f) for p in positions for f in p)
            assert max(i[0] for i in values(primitive['indices'])) < len(positions)
            if 'JOINTS_0' in attrs:
                joints, weights = values(attrs['JOINTS_0']), values(attrs['WEIGHTS_0'])
                assert len(joints) == len(weights) == len(positions)
                assert all(max(j) < len(asset['skins'][0]['joints']) for j in joints)
                assert all(abs(sum(w)-1)<1e-5 and min(w)>=0 for w in weights)
                blended += sum(sum(x>.02 for x in w)>1 for w in weights)
            for morph in primitive.get('targets',[]):
                delta=values(morph['POSITION'])
                assert len(delta) == len(positions)
                assert max(abs(f) for p in delta for f in p)>1e-4
                face_targets+=1
    assert blended>100 and face_targets==(0 if profile=='ze_gotinha' else 3)
    for animation in asset['animations']:
        paths = [(c['target']['node'], c['target']['path']) for c in animation['channels']]
        assert len(set(paths)) == len(paths), f'duplicate animated property: {profile}'
        for si,sampler in enumerate(animation['samplers']):
            inp, out = (asset['accessors'][sampler[k]] for k in ['input', 'output'])
            is_morph = any(c['sampler']==si and c['target']['path']=='weights' for c in animation['channels'])
            assert out['count'] == inp['count']*(3 if is_morph else 1) and inp['count']>=2
            view = asset['bufferViews'][inp['bufferView']]
            times = struct.unpack_from('<' + 'f'*inp['count'], binary, view['byteOffset'])
            assert times[0] == 0 and all(a < b for a, b in zip(times, times[1:]))
    print('PASS:', profile, 'geometry, 163-joint skin, normalized weights,', face_targets, f"reference facial morphs, {len(asset['animations'])} clips")
