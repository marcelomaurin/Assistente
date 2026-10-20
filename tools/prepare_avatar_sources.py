"""Prepare the selected official CC0 art assets, never MakeHuman application code.

Usage: python tools/prepare_avatar_sources.py --archive path/to/package.zip
The official package URL and its checked SHA-256 are recorded below.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
from zipfile import ZipFile
from PIL import Image

SOURCE = Path(__file__).resolve().parent / 'avatar-source'
URL = 'https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip'
SHA256 = 'b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107'
SETS = {
    'clothes': ['male_casualsuit01', 'male_casualsuit02', 'male_casualsuit03',
                'male_worksuit01', 'male_elegantsuit01', 'female_casualsuit01',
                'shoes01', 'shoes05'],
    'hair': ['short02', 'short03', 'bob01', 'afro01'],
    'eyes': ['high-poly', 'materials'],
    'eyebrows': ['eyebrow001'],
    'teeth': ['teeth_base'],
    'skins': ['young_caucasian_male', 'young_caucasian_female', 'young_african_male',
              'young_african_female', 'old_caucasian_male'],
}

def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    args = parser.parse_args()
    assert hashlib.sha256(args.archive.read_bytes()).hexdigest() == SHA256, 'Archive checksum mismatch'
    records = []
    with ZipFile(args.archive) as archive:
        for name in sorted(archive.namelist()):
            parts = Path(name).parts
            if len(parts) != 3 or parts[0] not in SETS or parts[1] not in SETS[parts[0]]:
                continue
            if Path(name).suffix not in ('.obj', '.mhclo', '.mhmat', '.png'):
                continue
            raw = archive.read(name)
            path = SOURCE / 'system' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.suffix == '.png':
                image = Image.open(io.BytesIO(raw))
                image.thumbnail((2048, 2048) if parts[0] == 'skins' else (1024, 1024), Image.Resampling.LANCZOS)
                image.save(path, optimize=True)
            else:
                path.write_bytes(raw)
            records.append({'path': name, 'upstream_sha256': hashlib.sha256(raw).hexdigest(),
                            'prepared_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    lock = {'url': URL, 'archive_sha256': SHA256, 'license': 'CC0-1.0',
            'preparation': 'Textures resized to at most 2048px for skin and 1024px for other assets.',
            'files': records}
    (SOURCE / 'system-assets.lock.json').write_text(json.dumps(lock, indent=2) + '\n', encoding='utf-8')
    print('Prepared', len(records), 'CC0 art files')

if __name__ == '__main__':
    main()
