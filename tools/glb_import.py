"""Import an external glTF/GLB character (Avaturn, Tripo3D, others) as an
Assistente avatar.

The imported meshes keep their own geometry and textures. They receive the
Assistente skeleton (163 joints) by transferring skin weights from a
MakeHuman reference body posed like the import (T or A pose), are brought back
to the Assistente rest pose, and get the same clips and calibrated movements as
the bundled avatars. Facial animation is skeletal (jaw, lips, eyelids), as in
the runtime, which ignores morph targets.

    python tools/glb_import.py modelo.glb --id nome --name "Nome" [--source avaturn|tripo] [--male] [--avatars DIR]

Limits: the character must stand upright, facing the camera, in T or A pose;
long loose hair and wide skirts follow the nearest body part.
"""
import argparse
import base64
import copy
import json
import math
import struct
import sys
from pathlib import Path

import numpy as np

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

COMPONENT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


# ------------------------------------------------------------------ glTF

class Gltf:
    def __init__(self, path):
        self.path = Path(path)
        data = self.path.read_bytes()
        self.bin = b''
        if data[:4] == b'glTF':
            length = struct.unpack_from('<I', data, 8)[0]
            off = 12
            while off < length:
                clen, ctype = struct.unpack_from('<II', data, off)
                chunk = data[off + 8: off + 8 + clen]
                if ctype == 0x4E4F534A:
                    self.doc = json.loads(chunk.decode('utf-8'))
                elif ctype == 0x004E4942:
                    self.bin = chunk
                off += 8 + clen
        else:
            self.doc = json.loads(data.decode('utf-8'))
        self.buffers = []
        for b in self.doc.get('buffers', []):
            uri = b.get('uri')
            if uri is None:
                self.buffers.append(self.bin)
            elif uri.startswith('data:'):
                self.buffers.append(base64.b64decode(uri.split(',', 1)[1]))
            else:
                self.buffers.append((self.path.parent / uri).read_bytes())

    def view(self, index):
        v = self.doc['bufferViews'][index]
        buf = self.buffers[v['buffer']]
        start = v.get('byteOffset', 0)
        return buf[start:start + v['byteLength']], v.get('byteStride')

    def accessor(self, index):
        a = self.doc['accessors'][index]
        dtype = COMPONENT[a['componentType']]; width = WIDTH[a['type']]
        count = a['count']
        if 'bufferView' not in a:
            out = np.zeros((count, width), dtype=np.float64)
        else:
            raw, stride = self.view(a['bufferView'])
            item = np.dtype(dtype).itemsize * width
            off = a.get('byteOffset', 0)
            if stride and stride != item:
                rows = [np.frombuffer(raw, dtype=dtype, count=width, offset=off + i * stride) for i in range(count)]
                out = np.array(rows, dtype=np.float64)
            else:
                out = np.frombuffer(raw, dtype=dtype, count=count * width, offset=off).reshape(count, width).astype(np.float64)
        if a.get('normalized'):
            out /= float(np.iinfo(dtype).max)
        return out

    def image_bytes(self, index):
        img = self.doc['images'][index]
        if 'bufferView' in img:
            raw, _ = self.view(img['bufferView'])
            ext = '.jpg' if 'jpeg' in img.get('mimeType', '') else '.png'
            return bytes(raw), ext
        uri = img['uri']
        if uri.startswith('data:'):
            ext = '.jpg' if 'jpeg' in uri[:30] else '.png'
            return base64.b64decode(uri.split(',', 1)[1]), ext
        p = self.path.parent / uri
        return p.read_bytes(), p.suffix.lower()

    def node_matrix(self, node):
        if 'matrix' in node:
            return np.array(node['matrix'], dtype=np.float64).reshape(4, 4).T
        t = np.array(node.get('translation', [0, 0, 0]), float)
        x, y, z, w = node.get('rotation', [0, 0, 0, 1])
        r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        s = np.array(node.get('scale', [1, 1, 1]), float)
        m = np.eye(4); m[:3, :3] = r * s[None, :]; m[:3, 3] = t
        return m

    def world_matrices(self):
        nodes = self.doc.get('nodes', [])
        parent = {c: i for i, n in enumerate(nodes) for c in n.get('children', [])}
        cache = {}

        def world(i):
            if i not in cache:
                local = self.node_matrix(nodes[i])
                cache[i] = world(parent[i]) @ local if i in parent else local
            return cache[i]
        return [world(i) for i in range(len(nodes))]

    def primitives(self):
        """Rest-pose primitives in world space: positions, uv, triangles, material index."""
        worlds = self.world_matrices()
        out = []
        for ni, node in enumerate(self.doc.get('nodes', [])):
            if 'mesh' not in node:
                continue
            mesh = self.doc['meshes'][node['mesh']]
            for prim in mesh['primitives']:
                if prim.get('mode', 4) != 4:
                    continue
                attrs = prim['attributes']
                p = self.accessor(attrs['POSITION'])[:, :3]
                if 'skin' in node and 'JOINTS_0' in attrs:
                    skin = self.doc['skins'][node['skin']]
                    ibm = self.accessor(skin['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1) \
                        if 'inverseBindMatrices' in skin else np.tile(np.eye(4), (len(skin['joints']), 1, 1))
                    joints = self.accessor(attrs['JOINTS_0']).astype(int)
                    weights = self.accessor(attrs['WEIGHTS_0'])
                    mats = np.array([worlds[j] @ ibm[k] for k, j in enumerate(skin['joints'])])
                    ph = np.c_[p, np.ones(len(p))]
                    acc = np.zeros((len(p), 4))
                    for c in range(4):
                        acc += weights[:, c:c + 1] * np.einsum('nij,nj->ni', mats[joints[:, c]], ph)
                    p = acc[:, :3] / np.maximum(weights.sum(1, keepdims=True), 1e-9)
                else:
                    p = (worlds[ni] @ np.c_[p, np.ones(len(p))].T).T[:, :3]
                uv = self.accessor(attrs['TEXCOORD_0'])[:, :2] if 'TEXCOORD_0' in attrs else np.zeros((len(p), 2))
                idx = self.accessor(prim['indices'])[:, 0].astype(np.int64) if 'indices' in prim else np.arange(len(p))
                out.append({'name': mesh.get('name') or f'malha{len(out)}', 'p': p, 'uv': uv,
                            'tri': idx.reshape(-1, 3), 'material': prim.get('material')})
        return out


# ------------------------------------------------------------------ reference rig

def reference_avatar(avatar_id, name, female, avatars):
    import avatar_spec
    spec = avatar_spec.default_spec(avatar_id, name, female)
    spec['hair'] = None
    g = avatar_spec.register(spec)
    if avatars:
        g.ROOT = Path(avatars)
    return g, g.Avatar(avatar_id)


def arm_angle(points, height, shoulder_y, shoulder_x, side):
    """Downward angle (degrees) of an arm from the shoulder to the farthest hand point."""
    s = points[(np.sign(points[:, 0]) == side) & (points[:, 1] > .45 * height)]
    if len(s) == 0:
        return 0.0
    hand = s[np.argmax(np.abs(s[:, 0]))]
    return math.degrees(math.atan2(shoulder_y - hand[1], abs(hand[0]) - shoulder_x))


def arm_transforms(av, delta_l, delta_r):
    """Per-bone 4x4 transforms raising each arm subtree by delta (degrees) about +Z at the shoulder."""
    nodes = av.doc['nodes']
    names = av.bones
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get('children', []):
            parent[c] = i
    index = {nodes[av.bone_nodes[b]]['name']: b for b in names}
    T = np.tile(np.eye(4), (len(names), 1, 1))
    for side, delta, sign in (('L', delta_l, 1), ('R', delta_r, -1)):
        root = av.bone_nodes['upperarm01.' + side]
        pivot = np.asarray(av.origins['upperarm01.' + side])
        a = math.radians(delta) * sign
        rot = np.eye(4)
        rot[:2, :2] = [[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]]
        m = np.eye(4); m[:3, 3] = pivot
        mi = np.eye(4); mi[:3, 3] = -pivot
        M = m @ rot @ mi
        for bi, b in enumerate(names):
            n = av.bone_nodes[b]
            while n is not None and n != root:
                n = parent.get(n)
            if n == root:
                T[bi] = M
    return T


def skin(points, weights, T):
    ph = np.c_[points, np.ones(len(points))]
    blended = np.einsum('nb,bij->nij', weights, T)
    out = np.einsum('nij,nj->ni', blended, ph)
    return out[:, :3]


# ------------------------------------------------------------------ import

def import_glb(path, avatar_id, name, source='glb', female=True, avatars=None, calibrate=True, log=print):
    from scipy.spatial import cKDTree
    import avatar_spec
    gl = Gltf(path)
    from tripo_rig_import import supports_rig, import_rigged_glb
    if supports_rig(gl):
        return import_rigged_glb(gl, avatar_id, name, source, female, avatars, calibrate, log)
    prims = gl.primitives()
    if not prims:
        raise ValueError('o arquivo não tem malhas')
    allp = np.vstack([p['p'] for p in prims])
    g, av = reference_avatar(avatar_id, name, female, avatars)
    ref = av.world(av.p)
    groups = av.groups
    keep_groups = {'body', 'helper-l-eye', 'helper-r-eye', 'helper-upper-teeth', 'helper-lower-teeth'}
    ref_idx = np.unique(av.faces[np.isin(groups, list(keep_groups)), :, 0])
    body_idx = np.unique(av.faces[groups == 'body', :, 0])
    ref_h = ref[body_idx, 1].max() - ref[body_idx, 1].min()

    # Orientation: glTF is Y-up; make the character face +Z. Toes reach
    # farther in front of the ankles than the heels behind them.
    def facing_back(points):
        lo_, hi_ = points.min(0), points.max(0); h = hi_[1] - lo_[1]
        ankle = points[(points[:, 1] > lo_[1] + .04 * h) & (points[:, 1] < lo_[1] + .07 * h)]
        sole = points[points[:, 1] < lo_[1] + .025 * h]
        if len(ankle) < 10 or len(sole) < 10:
            return False
        c = np.median(ankle[:, 2])
        return (sole[:, 2].max() - c) < (c - sole[:, 2].min())
    if facing_back(allp):
        log('Girando 180° para olhar para a frente')
        for p in prims:
            p['p'][:, [0, 2]] *= -1
        allp = np.vstack([p['p'] for p in prims])
    # Scale to the reference height, feet on the floor, torso centred.
    lo, hi = allp.min(0), allp.max(0)
    scale = ref_h / (hi[1] - lo[1])
    def centre(points, lo_y, h):
        # Central column of the torso: arms (A or T pose) stay outside |x| < 8% of the height.
        cx = (points[:, 0].min() + points[:, 0].max()) / 2
        band = points[(points[:, 1] > lo_y + .52 * h) & (points[:, 1] < lo_y + .70 * h) & (np.abs(points[:, 0] - cx) < .08 * h)]
        return np.array([cx, lo_y, (band[:, 2].min() + band[:, 2].max()) / 2])
    shift = centre(allp, lo[1], hi[1] - lo[1])
    target = centre(ref[body_idx], ref[body_idx, 1].min(), ref_h)
    for p in prims:
        p['p'] = (p['p'] - shift) * scale + target
    allp = np.vstack([p['p'] for p in prims])

    # Pose the reference arms like the import.
    sh = av.origins['upperarm01.L']
    a_imp_l = arm_angle(allp, ref_h, sh[1], abs(sh[0]), 1)
    a_imp_r = arm_angle(allp, ref_h, sh[1], abs(sh[0]), -1)
    a_ref_l = arm_angle(ref[body_idx], ref_h, sh[1], abs(sh[0]), 1)
    a_ref_r = arm_angle(ref[body_idx], ref_h, sh[1], abs(sh[0]), -1)
    dl, dr = a_ref_l - a_imp_l, a_ref_r - a_imp_r
    log(f'Pose dos braços: importado {a_imp_l:.0f}°/{a_imp_r:.0f}°, referência {a_ref_l:.0f}°/{a_ref_r:.0f}°')
    W = av.weights
    T = arm_transforms(av, dl, dr)
    posed = skin(ref, W, T)

    # Weight transfer (inverse-distance over the nearest reference points).
    tree = cKDTree(posed[ref_idx])
    Tinv = np.linalg.inv(T)
    meshes = []
    for p in prims:
        d, k = tree.query(p['p'], k=8)
        w = 1.0 / np.maximum(d, 1e-4) ** 2
        w /= w.sum(1, keepdims=True)
        pw = np.einsum('nk,nkb->nb', w, W[ref_idx][k])
        pw /= np.maximum(pw.sum(1, keepdims=True), 1e-12)
        rest = skin(p['p'], pw, Tinv)
        meshes.append(dict(p, rest=rest, w=pw.astype(np.float32), dist=d[:, 0]))
    far = np.concatenate([m['dist'] for m in meshes])
    log(f'Transferência de pesos: distância mediana {np.median(far)*1000:.1f} mm, 95% {np.percentile(far,95)*1000:.1f} mm')

    # Materials and textures.
    folder = av.folder
    folder.mkdir(parents=True, exist_ok=True)
    tex_cache = {}

    def texture(info):
        if not info:
            return None
        tex = gl.doc['textures'][info['index']]
        src = tex.get('source')
        if src is None:
            return None
        if src not in tex_cache:
            data, ext = gl.image_bytes(src)
            f = folder / f'textura_{src}{ext}'
            f.write_bytes(data)
            tex_cache[src] = f
        return tex_cache[src]

    def material(mi, name):
        if mi is None:
            return av.material(name, (.8, .8, .8), .6)
        m = gl.doc['materials'][mi]
        pbr = m.get('pbrMetallicRoughness', {})
        color = tuple(pbr.get('baseColorFactor', [1, 1, 1, 1])[:3])
        return av.material(m.get('name', name), color, pbr.get('roughnessFactor', .6), pbr.get('metallicFactor', 0),
                           texture=texture(pbr.get('baseColorTexture')), normal=texture(m.get('normalTexture')),
                           alpha=m.get('alphaMode') in ('MASK', 'BLEND'))

    class Imported(type(av)):
        pass
    av.__class__ = Imported

    def build(self):
        biggest = max(range(len(meshes)), key=lambda i: len(meshes[i]['rest']))
        for i, m in enumerate(meshes):
            tri = m['tri']
            faces = np.stack([tri, tri], axis=2)
            uv = m['uv'].copy()
            morphs = [np.zeros_like(m['rest'])] * 3 if i == biggest else None
            node = self.mesh(m['name'], m['rest'], uv, faces, material(m['material'], m['name']), m['w'].astype(np.float64), morphs=morphs)
            if i == biggest:
                self.face_node = node
        self.animate()
        self.doc['buffers'] = [{'byteLength': len(self.binary), 'uri': 'data:application/octet-stream;base64,' + base64.b64encode(self.binary).decode()}]
        self.doc['extras'] = {'profile': self.profile, 'imported_from': source, 'file': Path(path).name,
                              'rig': 'Assistente MakeHuman skeleton, weights transferred from a posed reference', **self.stats}
        (self.folder / 'modelo.gltf').write_text(json.dumps(self.doc, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
        clips = ['idle', 'listening', 'thinking', 'talking', 'wave', 'walk']
        (self.folder / 'modelo.ini').write_text('[animations]\n' + '\n'.join(n + '=' + n for n in clips) + '\n', encoding='utf-8')
        (self.folder / 'avatar.json').write_text(json.dumps({'id': self.profile, 'name': name, 'model': 'modelo.gltf',
                                                             'source': source, 'version': 4}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    build(av)
    spec = avatar_spec.default_spec(avatar_id, name, female)
    spec['source'] = {'kind': source, 'file': Path(path).name}
    (folder / 'ficha.avatar.json').write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    log(f'MODELO {folder / "modelo.gltf"}')
    if calibrate:
        avatar_spec.calibrate_movements(avatar_id, Path(g.ROOT), log)
    return folder


def main(argv=None):
    p = argparse.ArgumentParser(description='Importa um personagem .glb/.gltf para o Assistente')
    p.add_argument('file'); p.add_argument('--id', required=True); p.add_argument('--name', required=True)
    p.add_argument('--source', default='glb'); p.add_argument('--male', action='store_true')
    p.add_argument('--avatars'); p.add_argument('--no-calibrate', action='store_true')
    a = p.parse_args(argv)
    import avatar_spec
    if not avatar_spec.ID_PATTERN.match(a.id):
        p.error('id inválido')
    import_glb(a.file, a.id, a.name, a.source, not a.male, a.avatars, not a.no_calibrate)


if __name__ == '__main__':
    main()
