"""Pack MakeHuman CC0 targets (data/targets/**/*.target) into one compressed npz.

Usage: python tools/pack_mh_targets.py <makehuman/data/targets> tools/avatar-source/mh-targets.npz
(writes mh-targets-1.npz, mh-targets-2.npz... next to the given name)
Each key is the target path relative to data/targets without extension
(for example 'nose/nose-scale-horiz-decr'); the value is an (N, 4) float32
array of [vertex index, dx, dy, dz]. Provenance: makehumancommunity/makehuman.
"""
import sys
from pathlib import Path
import numpy as np


def main(src, dest):
    src = Path(src)
    data = {}
    for f in sorted(src.rglob('*.target')):
        rows = []
        for line in f.read_text(errors='replace').splitlines():
            v = line.split()
            if v and not v[0].startswith('#'):
                rows.append([float(v[0]), float(v[1]), float(v[2]), float(v[3])])
        key = f.relative_to(src).with_suffix('').as_posix()
        data[key] = np.array(rows, dtype=np.float32).reshape(-1, 4)
    # Base mesh has < 65536 vertices: uint16 indices; float16 deltas keep
    # sub-micrometre precision at the avatar scale and halve the size.
    # Split into parts of at most ~18 MiB raw data so each compressed file
    # stays well below transfer limits; readers load every part.
    dest = Path(dest)
    for old in dest.parent.glob(dest.stem + '*.npz'):
        old.unlink()
    parts, current, size = [], {}, 0
    for k, v in data.items():
        name = k.replace('/', '__')
        current[name + '.i'] = v[:, 0].astype(np.uint16)
        current[name + '.d'] = v[:, 1:].astype(np.float16)
        size += len(v) * 8
        if size > 18 << 20:
            parts.append(current); current, size = {}, 0
    if current:
        parts.append(current)
    for n, part in enumerate(parts):
        np.savez_compressed(dest.with_name(f'{dest.stem}-{n + 1}.npz'), **part)
    print(len(data), 'targets ->', [f'{f.name} {f.stat().st_size // 1024} KiB' for f in sorted(dest.parent.glob(dest.stem + '-*.npz'))])


if __name__ == '__main__':
    main(*sys.argv[1:3])
