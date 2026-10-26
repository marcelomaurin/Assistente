"""Round trip of the GLB importer: a reference body exported in T pose as a
static GLB must come back to the Assistente rest pose with the reference
skin weights. No network, GPU or Windows needed."""
import json, struct, sys, tempfile, shutil
from pathlib import Path
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import glb_import as gi


def write_glb(path, p, tri, color=(0.8, 0.6, 0.5)):
    pos = p.astype('<f4').tobytes(); idx = tri.astype('<u4').tobytes()
    binary = pos + idx
    doc = {'asset': {'version': '2.0'}, 'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0, 'name': 'corpo'}],
           'meshes': [{'name': 'corpo', 'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1, 'material': 0}]}],
           'materials': [{'name': 'pele', 'pbrMetallicRoughness': {'baseColorFactor': list(color) + [1]}}],
           'buffers': [{'byteLength': len(binary)}],
           'bufferViews': [{'buffer': 0, 'byteOffset': 0, 'byteLength': len(pos)}, {'buffer': 0, 'byteOffset': len(pos), 'byteLength': len(idx)}],
           'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': len(p), 'type': 'VEC3', 'min': p.min(0).tolist(), 'max': p.max(0).tolist()},
                         {'bufferView': 1, 'componentType': 5125, 'count': tri.size, 'type': 'SCALAR'}]}
    j = json.dumps(doc).encode(); j += b' ' * (-len(j) % 4); binary += b'\0' * (-len(binary) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(binary))
    out += struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(binary), 0x004E4942) + binary
    Path(path).write_bytes(out)


CAL = '--quick' not in sys.argv
LOG = print if '-v' in sys.argv else (lambda *_: None)


def main():
    tmp = Path(tempfile.mkdtemp())
    try:
        avatars = tmp / 'AVATARES'; avatars.mkdir()
        for f in ('movimentos.json', 'colisoes.json'):
            shutil.copy(ROOT / 'AVATARES' / f, avatars / f)
        g, ref = gi.reference_avatar('referencia_t', 'Referência', True, avatars)
        P = ref.world(ref.p)
        body = ref.faces[ref.groups == 'body'][:, :, 0]
        sh = ref.origins['upperarm01.L']; h = P[:, 1].max() - P[:, 1].min()
        used = np.unique(body)
        a = gi.arm_angle(P[used], h, sh[1], abs(sh[0]), 1)
        T = gi.arm_transforms(ref, a, a)              # raise to T pose (0 degrees)
        tpose = gi.skin(P, ref.weights, T)
        remap = -np.ones(len(P), int); remap[used] = np.arange(len(used))
        glb = tmp / 'teste_tpose.glb'
        # Other scale and offset, and facing -Z: the importer must turn it around.
        write_glb(glb, (tpose[used] * [-1, 1, -1]) * 1.12 + [0.3, 0, -0.2], remap[body])
        folder = gi.import_glb(glb, 'importado_t', 'Importado', 'teste', True, avatars, calibrate=CAL, log=LOG)
        doc = json.loads((folder / 'modelo.gltf').read_text(encoding='utf-8'))
        assert len(doc['animations']) >= 60, 'clips missing'
        catalog = json.loads((avatars / 'movimentos.json').read_text(encoding='utf-8'))
        assert not CAL or all('importado_t' in m.get('profiles', {}) for m in catalog['movements']), 'movements not calibrated'
        # Geometry back in the rest pose: compare with the reference body.
        import base64
        raw = base64.b64decode(doc['buffers'][0]['uri'].split(',')[1])
        mesh = doc['meshes'][0]['primitives'][0]['attributes']['POSITION']
        acc = doc['accessors'][mesh]; view = doc['bufferViews'][acc['bufferView']]
        got = np.frombuffer(raw, '<f4', acc['count'] * 3, view['byteOffset']).reshape(-1, 3)
        from scipy.spatial import cKDTree
        d, _ = cKDTree(P[used]).query(got)
        assert np.percentile(d, 95) < 0.012, f'rest pose error {np.percentile(d, 95):.4f} m'
        print(f'PASS: GLB import round trip (T pose -> rest pose, 95% within {np.percentile(d,95)*1000:.1f} mm, {len(doc["animations"])} clips' + (', 53 movements calibrated)' if CAL else ')'))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
