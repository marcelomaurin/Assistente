"""Adapt an existing Tripo skin to the Assistente rig without surface transfer.

The authored skin weights remain authoritative. Map named source bones to
Assistente controls and bring the limbs to the reference bind pose with those
same weights, so inner sleeve vertices never acquire torso weights.
"""
import copy
import hashlib
import json
from pathlib import Path
import numpy as np


def supports_rig(gl):
    names = {n.get('name') for n in gl.doc.get('nodes', [])}
    required = {'Hip', 'Head', 'L_Upperarm', 'R_Upperarm', 'L_Forearm',
                'R_Forearm', 'L_Hand', 'R_Hand', 'L_Thigh', 'R_Thigh'}
    return bool(gl.doc.get('skins')) and required <= names


def bone_map(name):
    core = {'BoneRoot': 'root', 'Hip': 'spine05', 'Pelvis': 'spine04',
            'Waist': 'spine03', 'Spine01': 'spine02', 'Spine02': 'spine01',
            'NeckTwist01': 'neck01', 'NeckTwist02': 'neck02',
            'Head': 'head', 'FacialBone': 'head'}
    if name in core:
        return core[name]
    if name[:2] not in ('L_', 'R_'):
        raise ValueError('Osso Tripo sem mapeamento: ' + name)
    side = '.' + name[0]
    part = name[2:]
    limbs = {'Clavicle': 'clavicle', 'Upperarm': 'upperarm01',
             'UpperarmTwist01': 'upperarm02', 'UpperarmTwist02': 'upperarm02',
             'Forearm': 'lowerarm01', 'ForearmTwist01': 'lowerarm02',
             'ForearmTwist02': 'lowerarm02', 'ElbowShareBone': 'lowerarm01',
             'Hand': 'wrist', 'Thigh': 'upperleg01',
             'ThighTwist01': 'upperleg02', 'ThighTwist02': 'upperleg02',
             'Calf': 'lowerleg01', 'CalfTwist01': 'lowerleg02',
             'CalfTwist02': 'lowerleg02', 'KneeShareBone': 'lowerleg01',
             'Foot': 'foot', 'ToeBase': 'toe1-1', 'Eye': 'eye'}
    if part in limbs:
        return limbs[part] + side
    for source, target in [('Thumb', 1), ('Index', 2), ('Mid', 3), ('Ring', 4), ('Pinky', 5)]:
        if part.startswith(source) and part[len(source):] in ('1', '2', '3'):
            return f'finger{target}-{part[len(source):]}' + side
    raise ValueError('Osso Tripo sem mapeamento: ' + name)


def align_vector(source, target):
    a = np.asarray(source, float); b = np.asarray(target, float)
    na, nb = np.linalg.norm(a), np.linalg.norm(b)
    if min(na, nb) < 1e-9:
        raise ValueError('Segmento do esqueleto sem comprimento.')
    a, b = a / na, b / nb
    v = np.cross(a, b); c = float(np.clip(np.dot(a, b), -1, 1))
    if c > 1 - 1e-10:
        return np.eye(3)
    if c < -1 + 1e-10:
        axis = np.cross(a, np.eye(3)[np.argmin(np.abs(a))]); axis /= np.linalg.norm(axis)
        return 2 * np.outer(axis, axis) - np.eye(3)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k / (1 + c)


def drop_orphan_channels(doc):
    """Remove animation channels without a target node (the facial morph
    track when the imported character has no morph mesh). glTF loaders such
    as three.js reject them, and they animate nothing."""
    for anim in doc.get('animations', []):
        keep = [c for c in anim['channels'] if c['target'].get('node') is not None]
        used = sorted({c['sampler'] for c in keep})
        remap = {old: new for new, old in enumerate(used)}
        anim['samplers'] = [anim['samplers'][i] for i in used]
        for c in keep:
            c['sampler'] = remap[c['sampler']]
        anim['channels'] = keep


def clean_component_weights(points, weights, names, positions, height):
    """Prevent relaxed-pose autorig contacts from attaching pants to hands.

    Tripo exports separate garment components. Restrict anatomically impossible
    influences, filling only the removed mass from valid nearby vertices of the
    same component. Do not transfer weights across the body surface.
    """
    from scipy.spatial import cKDTree
    lo, hi = points.min(0), points.max(0)
    hip, head = positions['Hip'], positions['Head']
    arm = np.array([n.startswith(('L_', 'R_')) and any(
        token in n for token in ('Upperarm', 'Forearm', 'Elbow', 'Hand', 'Thumb', 'Index', 'Mid', 'Ring', 'Pinky')) for n in names])
    allowed = np.ones_like(weights, dtype=bool)
    category = ''
    if lo[1] < height * .25 and hi[1] < height * .72:
        category = 'lower-body'
        allowed[:, arm | np.array([n in ('Head', 'FacialBone', 'L_Eye', 'R_Eye') or n.startswith('Neck') for n in names])] = False
    elif lo[0] < hip[0] + height * .04 and hi[0] > hip[0] - height * .04 and lo[1] > height * .4 and hi[1] < head[1] - height * .02:
        category = 'torso'
        allowed[:, arm] = False
        for i, bone in enumerate(names):
            if 'Upperarm' in bone:
                shoulder = positions[bone[:2] + 'Upperarm']
                allowed[:, i] = (points[:, 1] > shoulder[1] - .08 * height) & (np.abs(points[:, 0] - hip[0]) > .035 * height)
    elif hi[1] > head[1] + height * .05 and lo[1] > height * .65:
        category = 'head-hair'
        allowed[:, arm] = False
    if not category:
        return weights, {'category': 'unchanged', 'repaired_vertices': 0}
    clean = weights * allowed
    lost = 1 - clean.sum(1)
    broken = lost > 1e-6
    if not broken.any():
        return weights, {'category': category, 'repaired_vertices': 0}
    valid = lost < .01
    if not valid.any():
        valid = clean.sum(1) > .1
    if not valid.any():
        raise ValueError('Componente sem pesos anatomicos aproveitaveis: ' + category)
    good = clean[valid]
    good /= np.maximum(good.sum(1, keepdims=True), 1e-12)
    distance, near = cKDTree(points[valid]).query(points[broken], k=min(8, int(valid.sum())))
    if near.ndim == 1:
        near = near[:, None]; distance = distance[:, None]
    blend = 1 / np.maximum(distance, .0001) ** 2
    blend /= blend.sum(1, keepdims=True)
    replacement = np.einsum('nk,nkb->nb', blend, good[near]) * allowed[broken]
    if np.any(replacement.sum(1) < 1e-12):
        raise ValueError('Nao foi possivel reparar os pesos de ' + category)
    replacement /= replacement.sum(1, keepdims=True)
    clean[broken] += replacement * lost[broken, None]
    clean /= clean.sum(1, keepdims=True)
    return clean, {'category': category, 'repaired_vertices': int(broken.sum()), 'maximum_removed_weight': float(lost.max())}


def import_rigged_glb(gl, avatar_id, name, source, female, avatars, calibrate, log):
    from glb_import import reference_avatar
    import avatar_spec
    prims = gl.primitives()
    if not prims:
        raise ValueError('Modelo sem triangulos.')
    g, av = reference_avatar(avatar_id, name, female, avatars)
    ref = {key: np.array(value, float) for key, value in av.origins.items()}
    source_world = gl.world_matrices()
    source_index = {n.get('name'): i for i, n in enumerate(gl.doc['nodes']) if n.get('name')}
    source_parent = {c: i for i, node in enumerate(gl.doc['nodes']) for c in node.get('children', [])}
    allp = np.vstack([p['p'] for p in prims])
    height = np.ptp(allp[:, 1])
    if height < 1e-8:
        raise ValueError('Altura do avatar invalida.')
    body_idx = np.unique(av.faces[av.groups == 'body', :, 0])
    reference_height = np.ptp(av.world(av.p)[body_idx, 1])
    scale = reference_height / height
    hip = source_world[source_index['Hip']][:3, 3]
    shift = np.array([hip[0], allp[:, 1].min(), hip[2]])
    positions = {key: (source_world[i][:3, 3] - shift) * scale for key, i in source_index.items()}

    # The Tripo L/R labels provide a stable facing cue, unlike a walking stance's
    # asymmetric heels. This adapter requires its upright +Z human convention.
    if positions['L_Upperarm'][0] <= positions['R_Upperarm'][0]:
        raise ValueError('Rig Tripo com orientacao invertida; normalize para Y acima e frente +Z.')

    transforms = {}
    def segment(start, end, rest_start, rest_end, target_start):
        r = align_vector(positions[end] - positions[start], ref[rest_end] - ref[rest_start])
        m = np.eye(4); m[:3, :3] = r; m[:3, 3] = target_start - r @ positions[start]
        transforms[source_index[start]] = m
        return r @ positions[end] + m[:3, 3]

    for side in ('L', 'R'):
        elbow = segment(f'{side}_Upperarm', f'{side}_Forearm', f'upperarm01.{side}',
                        f'lowerarm01.{side}', positions[f'{side}_Upperarm'])
        segment(f'{side}_Forearm', f'{side}_Hand', f'lowerarm01.{side}', f'wrist.{side}', elbow)
        knee = segment(f'{side}_Thigh', f'{side}_Calf', f'upperleg01.{side}',
                       f'lowerleg01.{side}', positions[f'{side}_Thigh'])
        ankle = segment(f'{side}_Calf', f'{side}_Foot', f'lowerleg01.{side}', f'foot.{side}', knee)
        segment(f'{side}_Foot', f'{side}_ToeBase', f'foot.{side}', f'toe1-1.{side}', ankle)

    def transform_for(index):
        cursor = index
        while cursor not in transforms and cursor in source_parent:
            cursor = source_parent[cursor]
        return transforms.get(cursor, np.eye(4))

    mappings = {}
    target_sources = {}
    for skin in gl.doc['skins']:
        for index in skin['joints']:
            source_name = gl.doc['nodes'][index]['name']; target = bone_map(source_name)
            if target not in av.bone_index:
                raise ValueError('Controle de destino ausente: ' + target)
            mappings[index] = target
            p = positions[source_name]; m = transform_for(index)
            target_sources.setdefault(target, []).append((source_name, m[:3, :3] @ p + m[:3, 3]))

    anchors = {}
    for target, entries in target_sources.items():
        # Auxiliary sharing bones must not move the real elbow/head pivot.
        preferred = [value for label, value in entries if not any(x in label for x in ('Twist', 'Share', 'Facial'))]
        anchors[target] = np.mean(preferred or [value for _, value in entries], axis=0)
    known = list(anchors)
    reference_anchors = np.array([ref[key] for key in known])
    displacements = np.array([anchors[key] - ref[key] for key in known])
    for bone in av.bones:
        if bone in anchors:
            av.origins[bone] = anchors[bone]
        else:
            distances = np.linalg.norm(reference_anchors - ref[bone], axis=1)
            nearest = np.argsort(distances)[:4]; weights = 1 / np.maximum(distances[nearest], .005) ** 2
            av.origins[bone] = ref[bone] + np.average(displacements[nearest], axis=0, weights=weights)
    for bone, spec in av.rig['bones'].items():
        parent = spec['parent']
        av.doc['nodes'][av.bone_nodes[bone]]['translation'] = (av.origins[bone] - (av.origins[parent] if parent else 0)).tolist()
    inverse = []
    for bone in av.bones:
        matrix = np.eye(4); matrix[:3, 3] = -av.origins[bone]; inverse.append(matrix.T.reshape(-1))
    av.doc['skins'][0]['inverseBindMatrices'] = av.acc(inverse, 'MAT4')

    # Preserve the authored materials and texture bytes without relabelling
    # the imported artwork as MakeHuman/CC0.
    av.folder.mkdir(parents=True, exist_ok=True)
    av.doc['images'] = []
    for i, _ in enumerate(gl.doc.get('images', [])):
        data, extension = gl.image_bytes(i); filename = f'textura_{i}{extension}'
        (av.folder / filename).write_bytes(data); av.doc['images'].append({'uri': filename})
    for key in ('textures', 'samplers', 'materials'):
        av.doc[key] = copy.deepcopy(gl.doc.get(key, []))

    source_primitives = [(node, primitive) for node in gl.doc['nodes'] if 'mesh' in node
                         for primitive in gl.doc['meshes'][node['mesh']]['primitives'] if primitive.get('mode', 4) == 4]
    if len(prims) != len(source_primitives):
        raise ValueError('Primitivas do modelo nao correspondem ao rig.')
    total_weight_error = 0.
    repairs = []
    for primitive, (node, definition) in zip(prims, source_primitives):
        attrs = definition['attributes']
        if 'skin' not in node or 'JOINTS_0' not in attrs or 'WEIGHTS_0' not in attrs:
            raise ValueError('Malha sem pesos no arquivo rigado: ' + primitive['name'])
        joint_nodes = gl.doc['skins'][node['skin']]['joints']
        joints = gl.accessor(attrs['JOINTS_0']).astype(int)
        weights = gl.accessor(attrs['WEIGHTS_0'])
        if np.any(weights < 0) or not np.isfinite(weights).all():
            raise ValueError('Pesos de pele invalidos.')
        weights /= np.maximum(weights.sum(1, keepdims=True), 1e-12)
        points = (primitive['p'] - shift) * scale
        dense = np.zeros((len(points), len(joint_nodes)))
        rows = np.arange(len(points))
        for channel in range(joints.shape[1]):
            np.add.at(dense, (rows, joints[:, channel]), weights[:, channel])
        dense, repair = clean_component_weights(points, dense,
            [gl.doc['nodes'][index]['name'] for index in joint_nodes], positions, reference_height)
        repairs.append({'mesh': primitive['name'], **repair})
        restored = np.zeros_like(points); mapped = np.zeros((len(points), len(av.bones)))
        for source_joint, index in enumerate(joint_nodes):
            selected = dense[:, source_joint] > 0
            if not selected.any():
                continue
            m = transform_for(index); contribution = dense[selected, source_joint]
            restored[selected] += ((m[:3, :3] @ points[selected].T).T + m[:3, 3]) * contribution[:, None]
            mapped[selected, av.bone_index[mappings[index]]] += contribution
        total_weight_error = max(total_weight_error, float(np.max(np.abs(mapped.sum(1) - 1))))
        faces = np.stack([primitive['tri'], primitive['tri']], axis=2)
        av.mesh(primitive['name'], restored, primitive['uv'], faces, primitive['material'], mapped)

    av.animate()
    drop_orphan_channels(av.doc)
    av.doc['buffers'] = [{'byteLength': len(av.binary), 'uri': 'data:application/octet-stream;base64,' + __import__('base64').b64encode(av.binary).decode()}]
    av.doc['asset'] = copy.deepcopy(gl.doc.get('asset', {'version': '2.0'}))
    av.doc['asset']['generator'] = 'Assistente: Tripo rig adapter; authored mesh, textures and skin weights'
    av.doc['extras'] = {'profile': avatar_id, 'imported_from': source, 'file': gl.path.name,
                        'source_sha256': hashlib.sha256(gl.path.read_bytes()).hexdigest(),
                        'source_joints': len(mappings), 'rig': 'Assistente controls mapped from original Tripo skin',
                        'weight_transfer': 'original weights mapped by bone name with component-specific cleanup; no nearest-surface transfer',
                        'component_weight_repairs': repairs,
                        'weight_normalization_error': total_weight_error, **av.stats}
    (av.folder / 'modelo.gltf').write_text(json.dumps(av.doc, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    (av.folder / 'modelo.ini').write_text('[animations]\n' + '\n'.join(n + '=' + n for n in ('idle', 'listening', 'thinking', 'talking', 'wave', 'walk')) + '\n', encoding='utf-8')
    (av.folder / 'avatar.json').write_text(json.dumps({'id': avatar_id, 'name': name, 'model': 'modelo.gltf', 'source': source, 'version': 4}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    spec = avatar_spec.default_spec(avatar_id, name, female)
    spec['source'] = {'kind': source, 'file': gl.path.name, 'rigged': True}
    (av.folder / 'ficha.avatar.json').write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    log(f'Rig original preservado: {len(mappings)} ossos mapeados para {len(av.bones)} controles; erro de normalizacao {total_weight_error:.2g}')
    log(f'MODELO {av.folder / "modelo.gltf"}')
    if calibrate:
        avatar_spec.calibrate_movements(avatar_id, Path(g.ROOT), log)
    return av.folder
