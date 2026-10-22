"""Require a complete, connected skinned body, independently of the clothes.

Uses only the Python standard library. Run against the bundled glTF profiles.
"""
import base64
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def source_triangle_count():
    group, count = 'body', 0
    for line in (ROOT / 'tools/avatar-source/base.obj').read_text().splitlines():
        words = line.split()
        if not words:
            continue
        if words[0] == 'g':
            group = words[1]
        elif words[0] == 'f' and group == 'body':
            count += len(words) - 3
    return count


expected = source_triangle_count()
assert expected > 10000, 'Missing source body topology'
for path in sorted((ROOT / 'AVATARES').glob('*/modelo.gltf')):
    doc = json.loads(path.read_text(encoding='utf-8'))
    binary = base64.b64decode(doc['buffers'][0]['uri'].split(',')[1])

    def read(index):
        accessor = doc['accessors'][index]
        width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
        code = {5126: 'f', 5123: 'H', 5125: 'I'}[accessor['componentType']]
        offset = doc['bufferViews'][accessor['bufferView']].get('byteOffset', 0) + accessor.get('byteOffset', 0)
        return list(struct.iter_unpack('<' + code * width,
            binary[offset:offset + accessor['count'] * struct.calcsize('<' + code * width)]))

    primitive = doc['meshes'][0]['primitives'][0]
    indices = [v[0] for v in read(primitive['indices'])]
    assert len(indices) == expected * 3, f'{path.parent.name}: body was cropped ({len(indices)//3}/{expected} triangles)'
    attrs = primitive['attributes']
    positions, joints, weights = (read(attrs[key]) for key in ('POSITION', 'JOINTS_0', 'WEIGHTS_0'))
    # UV seams duplicate vertices. Weld equal positions for connectivity checks.
    canonical = {}
    representatives = []
    for point in positions:
        key = tuple(round(value, 7) for value in point)
        representatives.append(canonical.setdefault(key, len(canonical)))
    parents = list(range(len(canonical)))

    def find(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i

    for i in range(0, len(indices), 3):
        a, b, c = (representatives[v] for v in indices[i:i+3])
        parents[find(b)] = find(a)
        parents[find(c)] = find(a)
    bone_names = [doc['nodes'][i]['name'] for i in doc['skins'][0]['joints']]
    regions = ['head', 'spine', 'pelvis'] + [name + side for side in ('.L', '.R')
        for name in ('upperarm', 'lowerarm', 'wrist', 'upperleg', 'lowerleg', 'foot')]
    connected = None
    for region in regions:
        # Match numbered bones, e.g. upperarm01.L and upperarm02.L.
        prefix, _, side = region.partition('.')
        selected = {i for i, name in enumerate(bone_names)
                    if name.startswith(prefix) and (not side or name.endswith('.' + side))}
        components = {find(representatives[i]) for i, (js, ws) in enumerate(zip(joints, weights))
                      if sum(w for j, w in zip(js, ws) if j in selected) > 0.4}
        assert components, f'{path.parent.name}: missing anatomical region {region}'
        connected = components if connected is None else connected & components
    assert connected, f'{path.parent.name}: head, torso, arms, hands, legs and feet are disconnected'
    assert any(mesh['name'] == 'Vestuário deformável' for mesh in doc['meshes'][1:]), 'Clothing merged into body'
    print(f'PASS: {path.parent.name}, complete connected body ({expected} triangles), all limbs, separate clothing')
