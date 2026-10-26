"""Professora profiles: long layered hair, recoloured outfits and accessories.

Used by game_avatar.py for the profiles listed in STYLES. Everything is generated
from the vendored CC0 sources plus procedural geometry/textures; no network.
The result is a stylised game avatar inspired by a reference, not a likeness.
"""
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

FEMALE = {
    'macrodetails/universal-female-young-averagemuscle-averageweight': 1.0,
    'breast/female-young-averagemuscle-averageweight-maxcup-averagefirmness': .25,
    'neck/neck-scale-horiz-decr': .3,
}
MALE = {
    'macrodetails/universal-male-young-averagemuscle-averageweight': 1.0,
}
SOFT_BROWS = {'brow_thin': 1, 'brow_alpha': .9}
SOFT_FACE = {
    'head/head-oval': .5, 'chin/chin-width-decr': .3, 'chin/chin-prominent-decr': .2,
    'nose/nose-scale-horiz-decr': .25, 'nose/nose-point-width-decr': .3,
    'mouth/mouth-lowerlip-volume-incr': .35, 'mouth/mouth-upperlip-volume-incr': .25,
    'eyes/l-eye-scale-incr': .25, 'eyes/r-eye-scale-incr': .25,
    'cheek/l-cheek-volume-incr': .3, 'cheek/r-cheek-volume-incr': .3,
}
BLAZER = {'top': 'blazer', 'top_color': '#16171b', 'bottom': 'suit', 'badge': 'FATEC'}
PUMPS = {'shoes': ('#060607', '#3a3b40'), 'shoe_shell': True, 'shoe_rough': .22,
         'shoe_profile': [.050, .040, .036, .046, .07]}


def merge(*parts, **extra):
    out = {}
    for part in parts:
        for k, v in part.items():
            if k == 'targets':
                out.setdefault('targets', {}).update(v)
            else:
                out[k] = v
    for k, v in extra.items():
        if k == 'targets':
            out.setdefault('targets', {}).update(v)
        else:
            out[k] = v
    return out


STYLES = {
    # Dark brown long hair with caramel ends, glasses, white blouse and jeans.
    'professora': merge(
        {'targets': FEMALE}, {'targets': SOFT_FACE},
        hair_root=(46, 30, 22), hair_tip=(150, 98, 58),
        top='blouse', top_color='#f4f1ea', bottom='jeans',
        shoes=('#cdb49c', '#e6d6c4'), shoe_shell=True, shoe_rough=.45,
        glasses='dark', eyes=(64, 40, 24), smile=.45, skin_tint=(1.0, .95, .88),
        brow_color='#3a2a20', brow_thin=1, brow_alpha=.9,
        hair_layers=[(.003, 11, 1.0), (.008, 12, .975), (.013, 13, .95)],
        targets={'head/head-oval': .6, 'head/head-scale-horiz-decr': .15,
                 'chin/chin-width-decr': .6, 'chin/chin-bones-decr': .4,
                 'nose/nose-scale-horiz-decr': .35, 'nose/nose-point-width-decr': .4,
                 'nose/nose-scale-vert-decr': .2, 'nose/nose-volume-decr': .3,
                 'mouth/mouth-lowerlip-volume-incr': .6, 'mouth/mouth-upperlip-volume-incr': .5,
                 'mouth/mouth-scale-horiz-incr': .3,
                 'eyes/l-eye-scale-incr': .5, 'eyes/r-eye-scale-incr': .5,
                 'eyes/l-eye-height2-incr': .3, 'eyes/r-eye-height2-incr': .3,
                 'cheek/l-cheek-bones-incr': .35, 'cheek/r-cheek-bones-incr': .35,
                 'eyebrows/eyebrows-angle-up': .3, 'neck/neck-scale-horiz-decr': .4,
                 'forehead/forehead-temple-decr': .3}),
    # Honey blonde long hair, black suit, blue eyes, lanyard badge.
    'professora_loira': merge(
        {'targets': FEMALE}, {'targets': SOFT_FACE}, SOFT_BROWS, BLAZER, PUMPS,
        hair_root=(110, 82, 50), hair_tip=(232, 204, 150), hair_gradient=(.05, .55),
        eyes=(80, 126, 168), smile=.4, skin_tint=(1.0, .96, .92),
        targets={'nose/nose-scale-horiz-decr': .35, 'mouth/mouth-lowerlip-volume-incr': .5,
                 'mouth/mouth-upperlip-volume-incr': .4, 'cheek/l-cheek-bones-incr': .3,
                 'cheek/r-cheek-bones-incr': .3}),
    # Long voluminous curly dark hair with copper ends, gold hoops.
    'professora_cachos': merge(
        {'targets': FEMALE}, {'targets': SOFT_FACE}, SOFT_BROWS, BLAZER, PUMPS,
        hair_root=(20, 14, 11), hair_tip=(112, 64, 36), hair_gradient=(.3, 1.0),
        hair_curl=1, hair_volume=.035, hair_drape=.45, front_open=30,
        hair_ends=([0, 40, 62, 82, 100, 125, 180], [1.16, 1.15, 1.17, 1.25, 1.24, 1.12, 1.09]),
        hair_layers=[(.008, 21, 1.0), (.018, 22, .975), (.030, 23, .95), (.042, 24, .93)],
        earrings='hoops', eyes=(52, 32, 20), smile=.45,
        targets={'mouth/mouth-lowerlip-volume-incr': .5, 'mouth/mouth-upperlip-volume-incr': .4}),
    # Long straight black hair with soft brown highlights.
    'professora_cabelo_preto': merge(
        {'targets': FEMALE}, {'targets': SOFT_FACE}, SOFT_BROWS, BLAZER, PUMPS,
        hair_root=(14, 11, 10), hair_tip=(66, 44, 30), hair_gradient=(.35, 1.0),
        eyes=(48, 30, 20), smile=.35, skin_tint=(1.0, .95, .88),
        targets={'macrodetails/asian-female-young': 1.0, 'macrodetails/caucasian-female-young': -1.0,
                 'eyes/l-eye-epicanthus-in': .4, 'eyes/r-eye-epicanthus-in': .4}),
    # Wavy dark short hair, black suit, open white shirt, lanyard badge.
    'professor_terno': merge(
        {'targets': MALE}, BLAZER,
        hair_tint=('#0b0807', '#3d2e24'), shoes=('#050505', '#2c2c2e'), shoe_rough=.3,
        eyes=(70, 46, 28), smile=.35, skin_tint=(1.0, .94, .86), stubble=.25,
        targets={'chin/chin-width-incr': .2, 'head/head-square': .3}),
    # Short curly black hair, full short beard, black suit.
    'professor_barba': merge(
        {'targets': MALE}, BLAZER,
        hair_tint=('#050404', '#2a211c'), hair_fit=.55, shoes=('#050505', '#2c2c2e'), shoe_rough=.3,
        eyes=(52, 32, 20), smile=.4, beard=.85,
        targets={'chin/chin-width-incr': .3, 'mouth/mouth-lowerlip-volume-incr': .3}),
    # Short greying hair, thin metal glasses, suit with grey tie.
    'professor_oculos': merge(
        {'targets': MALE}, BLAZER,
        hair_tint=('#121212', '#8f8f8f'), glasses='metal', tie='#59606c',
        shoes=('#050505', '#2c2c2e'), shoe_rough=.3, eyes=(48, 32, 22), smile=.3,
        skin_tint=(1.0, .95, .86),
        targets={'macrodetails/asian-male-young': 1.0, 'macrodetails/caucasian-male-young': -1.0,
                 'eyes/l-eye-epicanthus-in': .4, 'eyes/r-eye-epicanthus-in': .4,
                 'head/head-age-incr': .35}),
}

MH_TARGETS = Path(__file__).resolve().parent / 'avatar-source'
_MH = None


class _Targets:
    """All packed parts (mh-targets-1.npz, -2.npz...) behind one mapping."""
    def __init__(self, folder):
        self.parts = [np.load(f) for f in sorted(folder.glob('mh-targets-*.npz'))]
        if not self.parts:
            raise FileNotFoundError(f'mh-targets-*.npz ausente em {folder}')
        self.files = [k for p in self.parts for k in p.files]

    def __getitem__(self, key):
        for p in self.parts:
            if key in p.files:
                return p[key]
        raise KeyError(key)


def mh_archive():
    global _MH
    if _MH is None:
        _MH = _Targets(MH_TARGETS)
    return _MH


def mh_target(name, count):
    """Delta of a MakeHuman CC0 target (path relative to data/targets), read
    from the packed archives built by pack_mh_targets.py."""
    arch = mh_archive()
    key = name.replace('/', '__')
    result = np.zeros((count, 3))
    result[arch[key + '.i'].astype(int)] = arch[key + '.d'].astype(np.float64)
    return result


ARM_BONES = ('upperarm', 'lowerarm', 'wrist', 'finger', 'metacarpal', 'hand')


def smoothstep(a, b, x):
    t = np.clip((np.asarray(x, dtype=float) - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- clothing

def outfit_texture(av, diffuse, style, normal=None, ao=None):
    """Paint the female casual suit as a white blouse over dark denim, or the
    elegant suit as a black blazer with a white blouse at the neckline."""
    if style.get('top') not in ('blouse', 'blazer'):
        return diffuse, normal, ao          # keep the garment's own texture
    im = Image.open(diffuse).convert('RGB')
    w, h = im.size
    gray = ImageOps.grayscale(im)
    if style['top'] == 'blouse':
        # UV islands: shirt front/back in the top band, sleeves at bottom right,
        # jeans at bottom left (female_casualsuit01).
        yy, xx = np.indices((h, w))
        shirt = (yy < .43 * h) | ((xx > .72 * w) & (yy > .58 * h))
        g = np.asarray(gray, dtype=float)
        # Keep only low-frequency folds; drops the logo and the orange piping.
        rng = np.random.default_rng(3)
        weave = (rng.normal(0, 1, (h, w)) * 6 + (np.indices((h, w)).sum(0) % 3 == 0) * 3)
        # Folds come from the normal/AO maps; the diffuse only keeps the weave,
        # so the printed logo and piping disappear.
        shade = np.clip(.97 + weave / 255 * .2, .88, 1.0)
        base = np.array(Image.new('RGB', (1, 1), style['top_color']).getpixel((0, 0)), dtype=float)
        blouse = base[None, None, :] * shade[:, :, None]
        denim = np.asarray(ImageOps.colorize(gray, '#0b1222', '#5b6f92'), dtype=float)
        # Darker, uniform wash: soften the bleached knees of the source texture.
        dmean = denim[~shirt].mean(0)
        denim = dmean + (denim - dmean) * .55
        out = np.where(shirt[:, :, None], blouse, denim * .82)
        result = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
        # The printed logo is also embossed in the normal and AO maps: flatten
        # the shirt islands there (soft folds remain from the AO blur).
        if normal is not None:
            n = np.asarray(Image.open(normal).convert('RGB').resize((w, h)), dtype=float)
            n[shirt] = [128, 128, 255]
            normal = av.folder / 'roupa_normal.png'
            Image.fromarray(n.astype(np.uint8)).save(normal)
        if ao is not None:
            a = Image.open(ao).convert('L').resize((w, h))
            blur = np.asarray(a.filter(ImageFilter.GaussianBlur(40)), dtype=float)
            a = np.asarray(a, dtype=float); a[shirt] = blur[shirt]
            ao = av.folder / 'roupa_ao.png'
            Image.fromarray(a.astype(np.uint8)).save(ao)
    else:
        # male_elegantsuit01: black jacket/trousers; the shirt V at the collar
        # becomes a plain white shirt, with or without a (recoloured) tie.
        rgb = np.asarray(im, dtype=float)
        r_, g_, b_ = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
        light = rgb.mean(2)
        cloth = np.asarray(ImageOps.colorize(gray, style.get('suit_dark', '#050506'), style.get('suit_light', '#4d4e54')), dtype=float)
        yy, xx = np.indices(light.shape)
        region = (yy < .21 * h) & (xx > .30 * w) & (xx < .48 * w)
        tie = region & (b_ > r_ + 12) & (light < 200)
        tie_mask = Image.fromarray((tie * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(3))
        tie = np.asarray(tie_mask) > 0
        knot = region & (light < 60) & (yy < .07 * h) & (xx > .34 * w) & (xx < .42 * w)
        shirt = region & ((light > 140) | tie | knot)
        shirt = np.asarray(Image.fromarray((shirt * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
        cuffs = (light > 150) & ~region
        white = np.array(Image.new('RGB', (1, 1), style.get('shirt_color', '#f3f3f1')).getpixel((0, 0)), float)
        shirt_px = white * np.clip(.80 + .2 * light / 255, .82, 1.0)[:, :, None]
        out = np.where((shirt | cuffs)[:, :, None], shirt_px, cloth)
        # Remember the tie/knot UV area: without a tie its geometry is removed,
        # leaving an open collar.
        av._tie_mask = np.asarray(Image.fromarray(((tie | knot) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
        if style.get('tie'):
            tc = np.array(Image.new('RGB', (1, 1), style['tie']).getpixel((0, 0)), float)
            stripes = (light - light[tie].mean()) / 255 if tie.any() else 0
            tie_px = tc * np.clip(1 + .5 * stripes, .7, 1.25)[:, :, None]
            out = np.where((tie | knot)[:, :, None], tie_px, out)
        result = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    path = av.folder / 'roupa.png'
    result.save(path)
    return path, normal, ao


def shoe_texture(av, diffuse, style):
    if not style.get('shoes'):
        return diffuse
    im = ImageOps.grayscale(Image.open(diffuse).convert('RGB'))
    im = ImageOps.autocontrast(im, cutoff=2)
    dark, light = style['shoes']
    path = av.folder / 'sapatos.png'
    ImageOps.colorize(im, dark, light).save(path)
    return path


def eye_texture(av, eyes, style):
    """Iris: one of the CC0 iris files ('iris'), or a recoloured brown iris ('eyes')."""
    if style.get('iris'):
        return Path(eyes).parent / f"{style['iris']}_eye.png"
    if not style.get('eyes'):
        return eyes
    im = Image.open(eyes).convert('RGBA')
    rgb = np.array(im)
    iris = rgb[:, :, :3].mean(2) < 130
    tone = rgb[iris, :3].mean(1, keepdims=True) / 90.0
    rgb[iris, :3] = np.clip(np.array(style['eyes'])[None, :] * tone, 0, 255)
    path = av.folder / 'olhos.png'
    Image.fromarray(rgb).save(path)
    return path


def eyebrow_texture(av, path, style):
    """Thinner, softer brows in the hair colour (the stock brow is heavy)."""
    im = Image.open(path).convert('RGBA')
    r, g, b, a = im.split()
    thin = style.get('brow_thin', 0)
    for _ in range(thin):
        a = a.filter(ImageFilter.MinFilter(3))
    a = a.point(lambda x: int(x * style.get('brow_alpha', 1.0)))
    color = Image.new('RGB', im.size, style.get('brow_color', '#3a2a20'))
    shade = ImageOps.autocontrast(ImageOps.grayscale(im.convert('RGB')))
    rgb = Image.composite(color, Image.new('RGB', im.size, (0, 0, 0)), shade.point(lambda x: 160 + x // 3))
    out = Image.merge('RGBA', (*rgb.split(), a))
    dest = av.folder / 'sobrancelhas.png'
    out.save(dest)
    return dest


def skin_texture(av, path, style):
    """Skin tone tint and painted beard/stubble (the base has no facial hair)."""
    tint = style.get('skin_tint')
    beard = max(style.get('beard', 0), style.get('stubble', 0))
    if not tint and not beard:
        return path
    im = Image.open(path).convert('RGB')
    rgb = np.asarray(im, dtype=float)
    if tint:
        rgb = rgb * np.array(tint)[None, None, :]
    if beard:
        mask = beard_mask(av, im.size, full=style.get('beard', 0) > 0)
        rng = np.random.default_rng(5)
        hairs = rng.random(rgb.shape[:2])
        dens = .55 + .45 * (hairs > .45)
        dark = np.array(style.get('beard_color', (22, 16, 13)), float)
        k = (mask * beard * dens)[:, :, None]
        rgb = rgb * (1 - k) + dark * k
    out = av.folder / 'pele.png'
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(out)
    return out


def beard_mask(av, size, full=True):
    """Rasterise the jaw/upper-lip area of the body UV map."""
    W, H = size
    P = av.world(av.p)
    eye = av.origins['eye.L']
    head = av.origins['head']
    faces = av.faces[av.groups == 'body']
    c = P[faces[:, :, 0]].mean(1)
    headw = av.weights[faces[:, :, 0], av.bone_index['head']].mean(1) + av.weights[faces[:, :, 0], av.bone_index['jaw']].mean(1)
    mouth_y = eye[1] - .072
    sel = (headw > .4) & (c[:, 1] < eye[1] - .045) & (c[:, 2] > head[2] - .005) & (c[:, 1] > eye[1] - .16)
    # Leave the lips and the area under the eyes clear.
    lips = (np.abs(c[:, 0]) < .028) & (np.abs(c[:, 1] - mouth_y) < .011) & (c[:, 2] > eye[2] - .01)
    cheek_top = c[:, 1] > eye[1] - .055 - .25 * np.abs(c[:, 0])
    sel &= ~lips & ~cheek_top
    if not full:
        sel &= (np.abs(c[:, 0]) < .06) | (c[:, 1] < eye[1] - .09)
    mask = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(mask)
    for f in faces[sel]:
        uv = av.uv[f[:, 1]]
        d.polygon([(u * W, v * H) for u, v in uv], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(W / 300))
    return np.asarray(mask, dtype=float) / 255


def hair_texture_tint(av, path, style):
    dark, light = style['hair_tint']
    im = Image.open(path).convert('RGBA')
    rgb = ImageOps.colorize(ImageOps.grayscale(im.convert('RGB')), dark, light)
    out = Image.merge('RGBA', (*rgb.split(), im.split()[3]))
    dest = av.folder / 'cabelo_curto.png'
    out.save(dest)
    return dest


def fit_hair_to_scalp(av, p, amount):
    """Pull a voluminous hair proxy (afro) towards the skull: short curls."""
    head = np.asarray(av.origins['head']) + [0, .055, -.005]
    d = p - head
    r = np.linalg.norm(d, axis=1, keepdims=True)
    inner = np.percentile(r, 5)
    return head + d / r * (inner + (r - inner) * amount)


# ---------------------------------------------------------------- long hair

def hair_texture(av, style, seed):
    """Strand texture: u across strands (tiles), v from scalp (0) to tips (1).
    Alpha cuts uneven, tapered ends; curly styles zigzag along the length."""
    rng = np.random.default_rng(seed)
    curly = style.get('hair_curl', 0)
    W, H = 512, 1024
    v = np.linspace(0, 1, H)[:, None]
    u = np.arange(W)[None, :]
    n = 70 if curly else 170
    centers = np.sort(rng.uniform(0, W, n))
    bright = rng.uniform(.6, 1.2, n)
    length = rng.uniform(.70, 1.0, n)
    width = rng.uniform(1.4, 3.4, n) * (4.0 if curly else 1)
    phase = rng.uniform(0, math.tau, n)
    freq = rng.uniform(85, 120, n) if curly else rng.uniform(26, 38, n)
    lum = np.zeros((H, W)); alpha = np.zeros((H, W))
    for c, b, L, wd, ph, fq in zip(centers, bright, length, width, phase, freq):
        if curly:
            amp = 16 + 10 * v                            # ringlets grow towards the ends
            x = c + amp * np.sin(v * fq + ph)
        else:
            x = c + 4.0 * np.sin(v * 7 + ph) * v ** 1.5  # gentle wave at the ends
        d = np.abs(((u - x + W / 2) % W) - W / 2)
        taper = np.clip((L - v) / .18, 0, 1)
        prof = np.exp(-(d / (wd * (0.65 + .35 * taper) + 1e-3)) ** 2) * (v < L)
        if curly:
            # Highlights on the outer side of each coil.
            prof *= .45 + .55 * np.clip(np.cos(v * fq + ph), 0, 1)
        lum = np.maximum(lum, prof * b)
        alpha = np.maximum(alpha, prof * np.clip((L - v) / .08, 0, 1))
    density = np.clip(1.3 - 1.25 * v ** 1.8, 0, 1)
    alpha = np.clip(np.maximum(alpha * 1.5, density), 0, 1)
    # Alpha-tested cards alias on sub-pixel strands: keep only solid coverage.
    alpha = np.where(alpha > .5, 1.0, 0.0)
    alpha = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3)), dtype=float) / 255
    lum = np.clip(.5 * density + .6 * lum, 0, 1.3)
    root = np.array(style['hair_root'], float); tip = np.array(style['hair_tip'], float)
    grad = smoothstep(*style.get('hair_gradient', (.2, .9)), v)[:, :, None]
    # Highlighted strands carry more of the tip colour (balayage).
    streak = (rng.uniform(0, 1, W) > .55)[None, :, None] * .35
    mix = np.clip(grad + streak * grad, 0, 1)
    color = root * (1 - mix) + tip * mix
    rgb = color * (.55 + .5 * lum[:, :, None])
    img = np.dstack([np.clip(rgb, 0, 255), np.clip(alpha * 255, 0, 255)]).astype(np.uint8)
    path = av.folder / f'cabelo_{seed}.png'
    Image.fromarray(img, 'RGBA').filter(ImageFilter.GaussianBlur(.5)).save(path)
    return path


def collision_points(av, extra):
    """Body (without arms) plus fitted garment points, in world space."""
    P = av.world(av.p)
    verts = np.unique(av.faces[av.groups == 'body', :, 0])
    arm = np.zeros(len(av.p))
    for name, i in av.bone_index.items():
        if name.startswith(ARM_BONES):
            arm += av.weights[:, i]
    keep = verts[arm[verts] < .35]
    pts = [P[keep]]
    for points, weights in extra:
        a = np.zeros(len(points))
        for name, i in av.bone_index.items():
            if name.startswith(ARM_BONES):
                a += weights[:, i]
        pts.append(points[a < .35])
    return np.vstack(pts)


def body_envelope(av, pts, top, axis_z, step=.004, dtheta=3.0):
    ys = np.arange(top + step, .9, -step)
    nth = int(360 / dtheta)
    ang = np.degrees(np.arctan2(pts[:, 0], pts[:, 2] - axis_z(pts[:, 1])))
    rad = np.hypot(pts[:, 0], pts[:, 2] - axis_z(pts[:, 1]))
    env = np.full((len(ys), nth), np.nan)
    yi = np.clip(((top + step - pts[:, 1]) / step).astype(int), 0, len(ys) - 1)
    ti = ((ang + 180) / dtheta).astype(int) % nth
    np.fmax.at(env, (yi, ti), rad)
    full = []
    for r in range(len(ys)):
        row = env[r]; ok = ~np.isnan(row)
        if ok.sum() >= 3:
            full.append(r)
            x = np.where(ok)[0]
            env[r] = np.interp(np.arange(nth), np.r_[x - nth, x, x + nth], np.r_[row[ok], row[ok], row[ok]])
    # Rows above the skull carry no points: use the first populated row.
    first = full[0]
    env[:first] = env[first]
    for r in range(first + 1, len(ys)):
        bad = np.isnan(env[r])
        env[r, bad] = env[r - 1, bad]
    from scipy.ndimage import gaussian_filter, maximum_filter
    raw = env.copy()
    env = gaussian_filter(env, sigma=(2.5, 1.5), mode=('nearest', 'wrap'))
    # Smoothing must never pull the hair inside protruding parts (ears).
    guard = gaussian_filter(maximum_filter(raw, size=(5, 5), mode=('nearest', 'wrap')), sigma=(2.0, 1.5), mode=('nearest', 'wrap'))
    env = np.maximum(env, guard)
    return ys, env


def long_hair(av, style, extra):
    """Layered long hair: shells draped over the head, shoulders and back.

    Columns run from the crown to the tips. Above the chin each column follows
    the skull; below it hangs (never moves back inwards), resting on the
    shoulders, chest or back. The face stays open; a middle parting shows scalp.
    """
    pts = collision_points(av, extra)
    head = av.origins['head']; eye = av.origins['eye.L']
    top = av.world(av.p)[:, 1].max()
    axis_z = lambda y: np.interp(y, [1.0, 1.30, 1.42, 2.0], [0.0, .015, head[2] + .005, head[2] + .005])
    ys, env = body_envelope(av, pts, top, axis_z)
    chin = av.origins['jaw'][1] - .05
    # Hanging hair: never jumps inwards, but can drift back towards the body
    # slowly (gravity drape) instead of standing off like a cape.
    hang = env.copy()
    drift = style.get('hair_drape', .45) * (ys[0] - ys[1])
    shoulder = av.origins['shoulder01.L'][1] - .03
    for r in range(1, len(ys)):
        d = drift if ys[r] < shoulder else 0.0
        hang[r] = np.maximum(env[r], hang[r - 1] - d)
    from scipy.ndimage import gaussian_filter1d
    hang = gaussian_filter1d(hang, 3, axis=0, mode='nearest')
    follow = smoothstep(chin - .02, chin + .03, ys)[:, None]
    env = follow * env + (1 - follow) * hang
    nth = env.shape[1]

    def envelope(theta, y):
        r = np.interp(y, ys[::-1], np.arange(len(ys))[::-1])
        c = (np.degrees(theta) + 180) / (360 / nth)
        r0 = int(np.clip(np.floor(r), 0, len(ys) - 2)); fr = r - r0
        c0 = int(np.floor(c)) % nth; c1 = (c0 + 1) % nth; fc = c - np.floor(c)
        v0 = env[r0, c0] * (1 - fc) + env[r0, c1] * fc
        v1 = env[r0 + 1, c0] * (1 - fc) + env[r0 + 1, c1] * fc
        return float(v0 * (1 - fr) + v1 * fr)

    hairline = eye[1] + style.get('hairline', .066)
    # Half opening (degrees) of the face/part at height y.
    open_low = style.get('front_open', 34)
    def opening(y):
        return float(np.interp(y, [.9, 1.30, chin, eye[1], hairline - .022, hairline, hairline + .01, 9],
                                  [open_low, open_low + 4, 40, 36, 27, 14, 1.2, 1.2]))
    ends = style.get('hair_ends', ([0, 40, 62, 82, 100, 125, 180], [1.13, 1.12, 1.14, 1.27, 1.25, 1.07, 1.03]))
    volume = style.get('hair_volume', 0.0)      # extra radius gained down the length
    curl = style.get('hair_curl', 0)
    rng = np.random.default_rng(7)
    apex = top + .008
    dome0 = top - .035
    layers = style.get('hair_layers', [(.005, 11, 1.0), (.012, 12, .975), (.020, 13, .95)])
    nu, nv = 132, 80
    s = np.linspace(0, 1, nv) ** 1.25
    for li, (offset, seed, scale) in enumerate(layers):
        tex = hair_texture(av, style, seed)
        mat = av.material(f'Cabelo longo camada {li+1}', rough=.78, texture=tex, alpha=True)
        clump_k = rng.integers(9, 14); clump_ph = rng.uniform(0, math.tau)
        verts = np.zeros((nv, nu + 1, 3)); uvs = np.zeros((nv, nu + 1, 2))
        for i in range(nu + 1):
            fu = i / nu
            theta_mid = math.radians(40 + (360 - 80) * fu)
            theta_mid = (theta_mid + math.pi) % (2 * math.pi) - math.pi
            yend = float(np.interp(abs(math.degrees(theta_mid)), *ends))
            yend += rng.uniform(-.018, .018) if 0 < i < nu else 0
            yend = apex - (apex - yend) * scale
            for j in range(nv):
                y = apex + offset - (apex + offset - yend) * s[j]
                o = opening(y)
                theta = math.radians(o + (360 - 2 * o) * fu)
                theta = (theta + math.pi) % (2 * math.pi) - math.pi
                # Layers sit flat on the scalp and separate along the length.
                spread = .3 + .7 * (1 - smoothstep(chin - .02, hairline, y))
                r = envelope(theta, y) + .0035 + offset * spread
                # Rounded crown: a dome from 5 cm below the top to the apex.
                if y > dome0:
                    r0 = envelope(theta, dome0) + .0035 + offset * spread
                    t = min((y - dome0) / (apex + offset - dome0), 1.0)
                    r = r0 * math.sqrt(1 - t * t)
                below = 1 - smoothstep(chin - .02, chin + .06, y)
                length_t = s[j]
                # Volume and clumps grow towards the ends.
                r += volume * below * (length_t ** .8)
                r += (.004 + .006 * curl) * below * math.sin(theta * clump_k + clump_ph + li) * length_t
                if curl:
                    # Ringlet clumps: bumps that twist down the length.
                    r += .007 * curl * (1 - smoothstep(top - .01, apex, y)) * math.sin(y * 95 + theta * 11 + li * 1.7)
                # Slight lift at the sides of the head.
                x = r * math.sin(theta); z = axis_z(y) + r * math.cos(theta)
                verts[j, i] = (x, y, z)
                uvs[j, i] = (fu * (9.0 if curl else 7.0), .004 + s[j] * .985)
        V = verts.reshape(-1, 3); T = uvs.reshape(-1, 2)
        faces = []
        idx = lambda j, i: j * (nu + 1) + i
        for j in range(nv - 1):
            for i in range(nu):
                a, b, c, d = idx(j, i), idx(j, i + 1), idx(j + 1, i), idx(j + 1, i + 1)
                faces += [[a, c, b], [b, c, d]]
        faces = np.array(faces)
        F = np.stack([faces, faces], axis=2)
        Wt = np.zeros((len(V), len(av.bones)), dtype=np.float32)
        y = V[:, 1]
        h = smoothstep(chin - .06, chin + .04, y)
        n = (1 - h) * (1 - smoothstep(1.28, chin - .06, y))
        sp = 1 - h - n
        Wt[:, av.bone_index['head']] = h
        Wt[:, av.bone_index['neck02']] += n * .5
        Wt[:, av.bone_index['neck01']] += n * .5
        Wt[:, av.bone_index['spine01']] += sp
        av.mesh(f'Cabelo longo em camadas {li+1}', V, T, F, mat, Wt)
    return True


# ---------------------------------------------------------------- accessories

def details(av, style, mats):
    dark, silver, white, gold = mats
    head = av.origins['head']; eye = av.origins['eye.L']; eyeR = av.origins['eye.R']
    height = (av.world(av.p).max(0) - av.world(av.p).min(0))[1]
    sc = height / 1.78
    if style.get('earrings') == 'hoops':
        for side in (1, -1):
            # Hoop in the ear's plane (YZ), hanging from the lobe.
            lobe = np.asarray(head) + np.array([side * .073, -.040, -.006]) * sc
            ring = [lobe + np.array([0, -.011 * (1 - math.cos(a)), .011 * math.sin(a)]) * sc for a in np.linspace(0, math.tau, 17)]
            for a, b in zip(ring, ring[1:]):
                av.segment('Argola dourada', a, b, .0012 * sc, gold, 'head')
    if style.get('glasses'):
        if style['glasses'] == 'metal':
            dark = av.material('Metal dos óculos', (.62, .64, .66), .25, .9)
        # Rounded-rectangle rims built from thin tubes (superellipse).
        for center in (eye, eyeR):
            c = np.asarray(center) + [0, .002 * sc, .031 * sc]
            pts = []
            for k in range(29):
                a = k / 28 * math.tau
                ca, sa = math.cos(a), math.sin(a)
                x = .0255 * sc * math.copysign(abs(ca) ** .5, ca)
                y = .0165 * sc * math.copysign(abs(sa) ** .5, sa)
                pts.append(c + [x, y, -.004 * sc * (x / (.0255 * sc)) ** 2])
            for a, b in zip(pts, pts[1:]):
                av.segment('Armação dos óculos', a, b, .0016 * sc, dark, 'head')
            side = np.sign(c[0])
            hinge = c + [side * .0255 * sc, .004 * sc, -.004 * sc]
            av.segment('Haste dos óculos', hinge, hinge + [side * .022 * sc, 0, -.085 * sc], .0016 * sc, dark, 'head')
        av.segment('Ponte dos óculos', np.asarray(eye) + [-.0255 * sc, .008 * sc, .031 * sc], np.asarray(eyeR) + [.0255 * sc, .008 * sc, .031 * sc], .0015 * sc, dark, 'head')
    # Thin necklace pendant.
    neck = av.origins['neck01']
    av.accessory('Pingente', neck + np.array([0, -.075, .085]) * sc, np.array([.006, .006, .003]) * sc, silver, 'spine01')
    if style.get('badge'):
        blue = av.material('Cordão azul', (.05, .09, .28), .6)
        chest = av.origins['spine01']
        top_l = neck + np.array([.045, .015, .045]) * sc; top_r = neck + np.array([-.045, .015, .045]) * sc
        card = chest + np.array([0, -.125, .135]) * sc
        garments = getattr(av, '_garments', None)
        if garments:
            pts = np.vstack([g[0] for g in garments])
            near = pts[(np.abs(pts[:, 0]) < .03) & (np.abs(pts[:, 1] - card[1]) < .015)]
            if len(near):
                card[2] = near[:, 2].max() + .008
        # Lanyard: from the neck sides over the garment down to the card.
        mid_l = (top_l + card) / 2 + np.array([.02, 0, .035]) * sc
        mid_r = (top_r + card) / 2 + np.array([-.02, 0, .035]) * sc
        mid_l[2] = max(mid_l[2], card[2]); mid_r[2] = max(mid_r[2], card[2])
        for a, b in ((top_l, mid_l), (mid_l, card + [.004, .03 * sc, 0]), (top_r, mid_r), (mid_r, card + [-.004, .03 * sc, 0])):
            av.segment('Cordão do crachá', a, b, .0035 * sc, blue, 'spine01')
        badge_material = av.material('Crachá', rough=.45, texture=badge_texture(av, style['badge']))
        badge(av, card, sc, badge_material)


def badge_texture(av, text):
    im = Image.new('RGB', (256, 360), (246, 247, 249))
    d = ImageDraw.Draw(im)
    try:
        font = ImageFont.truetype('DejaVuSans-Bold.ttf', 64)
    except OSError:
        font = ImageFont.load_default()
    d.rectangle([0, 0, 255, 70], fill=(18, 40, 96))
    d.rectangle([0, 300, 255, 359], fill=(160, 20, 30))
    bbox = d.textbbox((0, 0), text, font=font)
    d.text(((256 - (bbox[2] - bbox[0])) / 2, 150), text, fill=(18, 40, 96), font=font)
    d.rectangle([40, 240, 216, 252], fill=(150, 160, 175))
    path = av.folder / 'cracha.png'
    im.save(path)
    return path


def badge(av, center, sc, mat):
    w, h, t = .032 * sc, .045 * sc, .002 * sc
    c = np.asarray(center)
    corners = np.array([[-w, -h, t], [w, -h, t], [w, h, t], [-w, h, t],
                        [-w, -h, -t], [w, -h, -t], [w, h, -t], [-w, h, -t]]) + c
    uv = np.array([[0, 1], [1, 1], [1, 0], [0, 0]] * 2, dtype=float)
    quads = [(0, 1, 2, 3), (5, 4, 7, 6), (4, 0, 3, 7), (1, 5, 6, 2), (3, 2, 6, 7), (4, 5, 1, 0)]
    faces = []
    for a, b, cc, d in quads:
        faces += [[a, b, cc], [a, cc, d]]
    faces = np.array(faces)
    av.mesh('Crachá', corners - av.origins['spine01'], uv, np.stack([faces, faces], 2), mat, parent='spine01')


# ---------------------------------------------------------------- shoes

def vertex_normals(p, tri):
    n = np.zeros_like(p)
    fn = np.cross(p[tri[:, 1]] - p[tri[:, 0]], p[tri[:, 2]] - p[tri[:, 0]])
    for k in range(3):
        np.add.at(n, tri[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def shoe_shell(av, style):
    """Closed shoe (flat or pump) as a thin shell over the body's own foot, so
    it follows the foot exactly and never pokes through trouser hems."""
    P = av.world(av.p)
    faces = av.faces[av.groups == 'body']
    tri = faces[:, :, 0]
    normal = vertex_normals(P, tri)
    keep = np.zeros(len(P), bool)
    for side in 'LR':
        foot = av.weights[:, av.bone_index['foot.' + side]]
        for name, i in av.bone_index.items():
            if name.startswith('toe') and name.endswith('.' + side):
                foot = foot + av.weights[:, i]
        verts = np.where((foot > .3) & (P[:, 1] < .12))[0]
        z0, z1 = P[verts, 2].min(), P[verts, 2].max()
        t = (P[verts, 2] - z0) / (z1 - z0)
        cut = np.interp(t, [0, .45, .62, .8, 1], style.get('shoe_profile', [.058, .046, .040, .050, .08]))
        keep[verts[P[verts, 1] < cut]] = True
    inside = keep[tri].all(1)
    sel = faces[inside]
    shell = P + normal * style.get('shoe_thickness', .0028)
    dark, light = style['shoes']
    color = np.array(Image.new('RGB', (1, 1), dark).getpixel((0, 0))) / 255
    mat = av.material('Sapato fechado', tuple(color), rough=style.get('shoe_rough', .32), metal=.0)
    av.mesh('Calçados', shell, av.uv, sel, mat, av.weights)
