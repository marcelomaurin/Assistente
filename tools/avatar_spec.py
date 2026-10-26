"""Avatar specification ("ficha") -> Assistente avatar, plus importers.

One JSON format drives the Criador Avatar, the MakeHuman importer and the
generator. It stores MakeHuman modifier values (the same names as a .mhm
file), so a MakeHuman profile converts without loss of the shape, plus the
Assistente choices: hair, outfit, colours and accessories.

    python tools/avatar_spec.py build  ficha.avatar.json [--avatars DIR] [--preview] [--no-calibrate]
    python tools/avatar_spec.py import-mhm perfil.mhm [--id ID] [--name NOME] [--out ficha.avatar.json] [--build]
    python tools/avatar_spec.py catalog [--out catalogo.json]
    python tools/avatar_spec.py export-builtin ID --out ficha.avatar.json

The shape follows MakeHuman's own rules: each macro target is weighted by
the product of the values of its name components (gender, age, muscle,
weight, height, proportions, ethnicity, cup and firmness), and two-sided
modifiers ('nose/nose-scale-horiz-decr|incr') pick the side by sign.
"""
import argparse
import copy
import json
import re
import sys
from pathlib import Path

import numpy as np

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))

FORMAT = 'assistente-avatar-spec'
VERSION = 1
MODIFIER_FILES = ['modeling_modifiers.json', 'measurement_modifiers.json', 'bodyshapes_modifiers.json']
MACRO_DEFAULTS = {
    'macrodetails/Gender': .5, 'macrodetails/Age': .5,
    'macrodetails/African': 1 / 3, 'macrodetails/Asian': 1 / 3, 'macrodetails/Caucasian': 1 / 3,
    'macrodetails-universal/Muscle': .5, 'macrodetails-universal/Weight': .5,
    'macrodetails-height/Height': .5, 'macrodetails-proportions/BodyProportions': .5,
    'breast/BreastSize': .5, 'breast/BreastFirmness': .5,
}
OUTFITS = ['female_casualsuit01', 'male_casualsuit01', 'male_casualsuit02', 'male_casualsuit03',
           'male_elegantsuit01', 'male_worksuit01']
HAIRS = ['long', 'afro01', 'bob01', 'short02', 'short03']
SKINS = ['young_caucasian_female', 'young_caucasian_male', 'young_african_female',
         'young_african_male', 'old_caucasian_male']
IRIS = ['brown', 'brownlight', 'blue', 'bluegreen', 'deepblue', 'green', 'grey', 'ice', 'lightblue']
ID_PATTERN = re.compile(r'^[a-z0-9][a-z0-9_]{1,40}$')


# --------------------------------------------------------------- modifiers

def modifier_list():
    """All slider modifiers as [{'name','group','label','min','max','targets'}]."""
    out = []
    for name in MODIFIER_FILES:
        path = TOOLS / 'avatar-source' / 'mh-modifiers' / name
        for group in json.loads(path.read_text(encoding='utf-8')):
            g = group['group']
            for m in group['modifiers']:
                if 'macrovar' in m:
                    key = f"{g}/{m['macrovar']}"
                    out.append({'name': key, 'group': g, 'label': m['macrovar'], 'min': 0.0, 'max': 1.0,
                                'default': MACRO_DEFAULTS.get(key, .5), 'macro': True})
                elif 'min' in m:
                    t = m['target']
                    out.append({'name': f"{g}/{t}-{m['min']}|{m['max']}", 'group': g, 'label': f"{t} ({m['min']}/{m['max']})",
                                'min': -1.0, 'max': 1.0, 'default': 0.0,
                                'targets': [f"{g}/{t}-{m['min']}", f"{g}/{t}-{m['max']}"]})
                else:
                    t = m['target']
                    out.append({'name': f'{g}/{t}', 'group': g, 'label': t, 'min': 0.0, 'max': 1.0, 'default': 0.0,
                                'targets': [f'{g}/{t}']})
    return out


def _archive():
    from professora_avatar import mh_archive
    return mh_archive()


def macro_components(mods):
    """Component values used to weight the macro targets (MakeHuman A8 rules)."""
    v = dict(MACRO_DEFAULTS)
    v.update({k: float(x) for k, x in mods.items() if k in MACRO_DEFAULTS})
    g, age = v['macrodetails/Gender'], v['macrodetails/Age']
    c = {'female': 1 - g, 'male': g}
    if age < .5:
        young = max(0., (age - .1875) * 3.2)
        c.update(old=0., baby=max(0., 1 - age * 5.333), young=young, child=max(0., min(1., 5.333 * age) - young))
    else:
        old = max(0., age * 2 - 1)
        c.update(old=old, young=1 - old, child=0., baby=0.)

    def three(x, lo, mid, hi, mode='sum'):
        hi_v = max(0., x * 2 - 1); lo_v = max(0., 1 - x * 2)
        mid_v = 1 - (hi_v + lo_v) if mode == 'sum' else (1 - hi_v if hi_v > lo_v else 1 - lo_v)
        c.update({lo: lo_v, mid: mid_v, hi: hi_v})
    three(v['macrodetails-universal/Muscle'], 'minmuscle', 'averagemuscle', 'maxmuscle')
    three(v['macrodetails-universal/Weight'], 'minweight', 'averageweight', 'maxweight')
    three(v['macrodetails-height/Height'], 'minheight', 'averageheight', 'maxheight', 'max')
    three(v['macrodetails-proportions/BodyProportions'], 'uncommonproportions', 'regularproportions', 'idealproportions', 'max')
    three(v['breast/BreastSize'], 'mincup', 'averagecup', 'maxcup', 'max')
    three(v['breast/BreastFirmness'], 'minfirmness', 'averagefirmness', 'maxfirmness', 'max')
    races = np.array([v['macrodetails/African'], v['macrodetails/Asian'], v['macrodetails/Caucasian']], float)
    races = races / races.sum() if races.sum() > 0 else np.ones(3) / 3
    c.update(african=races[0], asian=races[1], caucasian=races[2], universal=1.0)
    return c


def shape_targets(mods):
    """Modifier values -> {target path: weight}, macro and regular."""
    arch = _archive()
    keys = sorted({k[:-2].replace('__', '/') for k in arch.files})
    comp = macro_components(mods)
    weights = {}
    for key in keys:
        folder, _, stem = key.rpartition('/')
        if not (folder.startswith('macrodetails') or folder == 'breast'):
            continue
        parts = stem.split('-')
        if not all(p in comp for p in parts):
            continue
        w = float(np.prod([comp[p] for p in parts]))
        if abs(w) > 1e-6:
            weights[key] = w
    known = {m['name']: m for m in modifier_list()}
    for name, value in mods.items():
        value = float(value)
        if name in MACRO_DEFAULTS or abs(value) < 1e-6:
            continue
        m = known.get(name)
        if m is None:
            continue           # unknown/unsupported modifier: reported by the importer
        if len(m['targets']) == 2:
            target = m['targets'][0] if value < 0 else m['targets'][1]
            weights[target] = weights.get(target, 0) + abs(value)
        else:
            weights[m['targets'][0]] = weights.get(m['targets'][0], 0) + value
    files = set(arch.files)
    return {k: w for k, w in weights.items() if k.replace('/', '__') + '.i' in files}


# --------------------------------------------------------------- spec

def default_spec(avatar_id='novo_avatar', name='Novo avatar', female=True):
    return {
        'format': FORMAT, 'version': VERSION, 'id': avatar_id, 'name': name,
        'modifiers': {'macrodetails/Gender': 0.0 if female else 1.0, 'macrodetails/Age': .5,
                      'macrodetails/Caucasian': 1.0, 'macrodetails/African': 0.0, 'macrodetails/Asian': 0.0},
        'skin': 'young_caucasian_female' if female else 'young_caucasian_male',
        'outfit': 'female_casualsuit01' if female else 'male_casualsuit01',
        'hair': 'long' if female else 'short02',
        'style': {'hair_root': [46, 30, 22], 'hair_tip': [120, 80, 50], 'eyes': [64, 40, 24], 'smile': .3}
        if female else {'hair_tint': ['#0d0a09', '#3a2c22'], 'eyes': [64, 40, 24], 'smile': .3},
        'source': {'kind': 'criador-avatar'},
    }


def validate(spec):
    errors = []
    if spec.get('format') != FORMAT:
        errors.append('formato desconhecido')
    if not ID_PATTERN.match(str(spec.get('id', ''))):
        errors.append('id deve ter letras minúsculas, números e _ (2 a 41 caracteres)')
    if spec.get('outfit') not in OUTFITS:
        errors.append(f"roupa inválida: {spec.get('outfit')}")
    if spec.get('hair') not in HAIRS + [None]:
        errors.append(f"cabelo inválido: {spec.get('hair')}")
    if spec.get('skin') not in SKINS:
        errors.append(f"pele inválida: {spec.get('skin')}")
    known = {m['name'] for m in modifier_list()}
    for k, v in spec.get('modifiers', {}).items():
        if k not in known:
            errors.append(f'modificador desconhecido: {k}')
        elif not isinstance(v, (int, float)) or not -1.0001 <= v <= 1.0001:
            errors.append(f'valor fora da faixa: {k}={v}')
    return errors


def style_from_spec(spec):
    style = copy.deepcopy(spec.get('style', {}))
    for k in ('hair_root', 'hair_tip', 'eyes', 'skin_tint', 'beard_color'):
        if isinstance(style.get(k), list):
            style[k] = tuple(style[k])
    for k in ('hair_tint', 'shoes'):
        if isinstance(style.get(k), list):
            style[k] = tuple(style[k])
    targets = shape_targets(spec.get('modifiers', {}))
    for k, w in style.get('targets', {}).items():
        targets[k] = targets.get(k, 0) + w
    style['targets'] = targets
    style.setdefault('top', None)
    # Recolouring maps belong to specific garments' UV layouts.
    if style['top'] == 'blouse' and spec.get('outfit') != 'female_casualsuit01':
        style['top'] = None
    if style['top'] == 'blazer' and spec.get('outfit') != 'male_elegantsuit01':
        style['top'] = None
    style.setdefault('hair_root', (46, 30, 22)); style.setdefault('hair_tip', (110, 72, 44))
    if spec.get('outfit') == 'male_elegantsuit01':
        style['top'] = style.get('top') or 'blazer'
        style.setdefault('top_color', '#16171b')
    return style


def register(spec):
    import game_avatar as g
    from professora_avatar import STYLES
    sid = spec['id']
    g.PROFILES[sid] = (spec['name'], None, spec['outfit'], spec.get('hair'), spec['skin'])
    STYLES[sid] = style_from_spec(spec)
    return g


def build(spec, avatars=None, preview=False, calibrate=True, log=print):
    errors = validate(spec)
    if errors:
        raise ValueError('; '.join(errors))
    g = register(spec)
    if avatars:
        g.ROOT = Path(avatars)
    avatar = g.Avatar(spec['id'])
    avatar.build()
    folder = avatar.folder
    used = {i['uri'] for i in json.loads((folder / 'modelo.gltf').read_text(encoding='utf-8')).get('images', [])}
    for f in folder.iterdir():
        if f.is_file() and f.suffix == '.png' and f.name not in used:
            f.unlink()
    (folder / 'ficha.avatar.json').write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    log(f'MODELO {folder / "modelo.gltf"}')
    if calibrate and not preview:
        calibrate_movements(spec['id'], Path(g.ROOT), log)
    return folder


def calibrate_movements(profile, avatars, log=print):
    """Add this avatar's collision-safe recipes to the shared movement catalog."""
    import repair_movement_paths as r
    from export_movement_timelines import layout
    r.ROOT = Path(avatars).parent
    path = Path(avatars) / 'movimentos.json'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    rig = r.Rig(profile); rig.step = 50
    for m in catalog['movements']:
        recipe = m.setdefault('profiles', {}).setdefault(profile, copy.deepcopy(
            {k: v for k, v in m.items() if k in ['duration_ms', 'transition_ms', 'return_ms', 'finish', 'interpolation', 'members']}))
        rig.repair(recipe)
    path.write_text(layout(catalog) + '\n', encoding='utf-8')
    log(f'MOVIMENTOS calibrados para {profile}')


# --------------------------------------------------------------- MakeHuman

MH_SKINS = {'young_caucasian_female', 'young_caucasian_male', 'young_african_female', 'young_african_male', 'old_caucasian_male'}


def import_mhm(path, avatar_id=None, name=None):
    """MakeHuman .mhm -> spec. Shape is exact; proxies map to the closest
    asset bundled with the Assistente, and the report lists every fallback."""
    report = []
    mods = {}
    proxies = {}
    skin = None
    eye_material = None
    mh_name = None
    for line in Path(path).read_text(encoding='utf-8', errors='replace').splitlines():
        v = line.split()
        if not v:
            continue
        if v[0] == 'modifier' and len(v) >= 3:
            mods[v[1]] = float(v[2])
        elif v[0] == 'name' and len(v) > 1:
            mh_name = ' '.join(v[1:])
        elif v[0] in ('hair', 'eyebrows', 'eyes', 'clothes', 'proxy', 'eyelashes', 'teeth', 'tongue') and len(v) > 1:
            proxies.setdefault(v[0], []).append(v[1])
        elif v[0] == 'skinMaterial' and len(v) > 1:
            skin = Path(v[1]).stem
        elif v[0] == 'material' and len(v) > 3 and 'eyes' in v[3]:
            eye_material = Path(v[3]).stem
    known = {m['name'] for m in modifier_list()}
    unknown = sorted(k for k in mods if k not in known)
    if unknown:
        report.append('Modificadores sem alvo no pacote (ignorados): ' + ', '.join(unknown))
    mods = {k: v for k, v in mods.items() if k in known}
    female = mods.get('macrodetails/Gender', .5) < .5
    race = max(('caucasian', 'african', 'asian'), key=lambda r: mods.get('macrodetails/' + r.capitalize(), 1 / 3))
    age_old = mods.get('macrodetails/Age', .5) > .8
    if skin not in MH_SKINS:
        guess = ('old_caucasian_male' if age_old and not female else
                 f"young_{'african' if race == 'african' else 'caucasian'}_{'female' if female else 'male'}")
        if skin:
            report.append(f'Pele "{skin}" substituída por "{guess}"')
        skin = guess
    hair_in = (proxies.get('hair') or [None])[0]
    hair = hair_in if hair_in in HAIRS else ('long' if (female or (hair_in or '').startswith(('long', 'ponytail', 'braid'))) else 'short02')
    if hair_in and hair_in != hair:
        report.append(f'Cabelo "{hair_in}" substituído por "{hair}"')
    clothes = proxies.get('clothes', [])
    outfit = next((c for c in clothes if c in OUTFITS), None)
    if outfit is None:
        outfit = 'female_casualsuit01' if female else 'male_casualsuit01'
        if clothes:
            report.append(f"Roupas {clothes} substituídas por \"{outfit}\"")
    style = {'smile': .2, 'hair_root': [46, 30, 22], 'hair_tip': [110, 72, 44]}
    if hair != 'long':
        style = {'smile': .2, 'hair_tint': ['#0d0a09', '#3a2c22']}
    if eye_material in IRIS:
        style['iris'] = eye_material
    spec = {
        'format': FORMAT, 'version': VERSION,
        'id': avatar_id or re.sub(r'[^a-z0-9_]+', '_', (mh_name or Path(path).stem).lower()).strip('_')[:40] or 'makehuman',
        'name': name or mh_name or Path(path).stem,
        'modifiers': mods, 'skin': skin, 'outfit': outfit, 'hair': hair, 'style': style,
        'source': {'kind': 'makehuman', 'file': Path(path).name, 'report': report},
    }
    return spec, report


# --------------------------------------------------------------- builtin

def export_builtin(profile):
    import game_avatar as g
    from professora_avatar import STYLES
    label, shape, outfit, hair, skin = g.PROFILES[profile]
    style = copy.deepcopy(STYLES.get(profile, {}))
    targets = style.pop('targets', {})
    if shape:
        targets['macrodetails/' + shape] = targets.get('macrodetails/' + shape, 0) + 1.0
    style['targets'] = targets
    for k, v in list(style.items()):
        if isinstance(v, tuple):
            style[k] = list(v)
    return {'format': FORMAT, 'version': VERSION, 'id': profile, 'name': label, 'modifiers': {},
            'skin': skin or 'young_caucasian_female', 'outfit': outfit, 'hair': hair, 'style': style,
            'source': {'kind': 'builtin'}}


def catalog():
    return {'modifiers': modifier_list(), 'outfits': OUTFITS, 'hairs': HAIRS, 'skins': SKINS, 'iris': IRIS,
            'defaults': MACRO_DEFAULTS}


def main(argv=None):
    p = argparse.ArgumentParser(description='Fichas de avatar do Assistente')
    sub = p.add_subparsers(dest='cmd', required=True)
    b = sub.add_parser('build'); b.add_argument('spec'); b.add_argument('--avatars'); b.add_argument('--preview', action='store_true', help='sem calibrar movimentos (prévia rápida)'); b.add_argument('--no-calibrate', action='store_true')
    i = sub.add_parser('import-mhm'); i.add_argument('mhm'); i.add_argument('--id'); i.add_argument('--name'); i.add_argument('--out'); i.add_argument('--build', action='store_true'); i.add_argument('--avatars')
    c = sub.add_parser('catalog'); c.add_argument('--out')
    e = sub.add_parser('export-builtin'); e.add_argument('profile'); e.add_argument('--out', required=True)
    n = sub.add_parser('new'); n.add_argument('--id', required=True); n.add_argument('--name', required=True); n.add_argument('--male', action='store_true'); n.add_argument('--out', required=True)
    a = p.parse_args(argv)
    if a.cmd == 'build':
        spec = json.loads(Path(a.spec).read_text(encoding='utf-8'))
        build(spec, a.avatars, a.preview, not a.no_calibrate)
    elif a.cmd == 'import-mhm':
        spec, report = import_mhm(a.mhm, a.id, a.name)
        for line in report:
            print('AVISO', line)
        out = Path(a.out or Path(a.mhm).with_suffix('.avatar.json'))
        out.write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print('FICHA', out)
        if a.build:
            build(spec, a.avatars)
    elif a.cmd == 'catalog':
        text = json.dumps(catalog(), ensure_ascii=False, indent=1)
        (Path(a.out).write_text(text + '\n', encoding='utf-8') if a.out else print(text))
    elif a.cmd == 'export-builtin':
        Path(a.out).write_text(json.dumps(export_builtin(a.profile), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    elif a.cmd == 'new':
        Path(a.out).write_text(json.dumps(default_spec(a.id, a.name, not a.male), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
