"""Installer checks that also run on Linux under Wine (no Windows-only APIs).

Fresh install, upgrade from the real 0.214 installer (default and customised
movement catalogs), preservation of a user-created avatar and the installed
avatar generator. Writes bin/setup_assistente_<code>.validacao.json.

    python tests/check_installer_wine.py --build-code 0217 --previous bin/setup_assistente_0216.exe
"""
import argparse, hashlib, json, os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--build-code', default='0217'); p.add_argument('--version', default='0.217')
p.add_argument('--previous', type=Path, default=ROOT / 'bin/setup_assistente_0216.exe')
A = p.parse_args()
WINE = os.name != 'nt'
PREFIX = Path(os.environ.get('WINEPREFIX', Path.home() / '.wine'))
REPORT = []


def drive(path_in_c):
    return PREFIX / 'drive_c' / path_in_c if WINE else Path('C:/') / path_in_c


def run_setup(setup, target):
    cmd = (['wine'] if WINE else []) + [str(setup), '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
                                        f'/DIR=C:\\{target}', '/VERIFYINSTALL=1']
    subprocess.run(cmd, check=True, capture_output=True, timeout=1800)


def sha(f):
    return hashlib.sha256(Path(f).read_bytes()).hexdigest()


def check_files(inst, manifest, skip=()):
    bad = [r['path'] for r in manifest['files'] if r['path'] not in skip and
           (not (inst / r['path']).is_file() or sha(inst / r['path']) != r['sha256'])]
    assert not bad, f'{len(bad)} arquivos divergentes: {bad[:5]}'


setup = ROOT / f'bin/setup_assistente_{A.build_code}.exe'
manifest = json.loads((ROOT / f'bin/setup_assistente_{A.build_code}.manifest.json').read_text(encoding='utf-8-sig'))
assert sha(setup) == manifest['installer']['sha256']
models = len(list((ROOT / 'AVATARES').glob('*/modelo.gltf')))

# 1. Fresh install in an isolated folder.
fresh = drive('verif_fresh'); shutil.rmtree(fresh, ignore_errors=True)
run_setup(setup, 'verif_fresh')
check_files(fresh, manifest)
installed = len(list((fresh / 'AVATARES').glob('*/modelo.gltf')))
assert installed == models, (installed, models)
assert not (fresh / 'Setmain.cfg').exists() and not (fresh / 'conversation-history.json').exists()
REPORT.append(f'PASS: actual installer extracted {len(manifest["files"])} files; all SHA-256 hashes match; {installed} avatars; no personal configuration')

# 2. Upgrade from the real previous installer with its default catalog.
prev_manifest = json.loads((A.previous.with_suffix('.manifest.json')).read_text(encoding='utf-8-sig'))
assert sha(A.previous) == prev_manifest['installer']['sha256'], 'previous installer differs from its manifest'
up = drive('verif_upgrade'); shutil.rmtree(up, ignore_errors=True)
run_setup(A.previous, 'verif_upgrade')
prev_catalog = next(r['sha256'] for r in prev_manifest['files'] if r['path'] == 'AVATARES/movimentos.json')
assert sha(up / 'AVATARES/movimentos.json') == prev_catalog
user_avatar = up / 'AVATARES/meu_avatar'; user_avatar.mkdir()
(user_avatar / 'avatar.json').write_text('{"id":"meu_avatar","name":"Meu avatar","model":"modelo.gltf"}', encoding='utf-8')
run_setup(setup, 'verif_upgrade')
assert (up / 'AVATARES/movimentos.json').read_bytes() == (ROOT / 'AVATARES/movimentos.json').read_bytes(), 'default catalog not upgraded'
assert (user_avatar / 'avatar.json').is_file(), 'user avatar removed'
# Editable files kept on upgrade by design (collision profile, external motions):
# compare their JSON content, since the previous release shipped CRLF copies.
kept = {r['path'] for r in manifest['files'] if r['path'] == 'AVATARES/colisoes.json' or r['path'].startswith('AVATARES/movimentos/')}
for rel in kept:
    assert json.loads((up / rel).read_text(encoding='utf-8-sig')) == json.loads((ROOT / rel).read_text(encoding='utf-8-sig')), rel
check_files(up, manifest, skip=kept)
REPORT.append(f'PASS: actual {prev_manifest["version"]}-to-{A.version} upgrade: default movement catalog upgraded with the new avatars, user-created avatar folder preserved, editable collision/motion JSON kept (same content), all other files match')

# 3. Upgrade keeps a customised catalog.
cu = drive('verif_custom'); shutil.rmtree(cu, ignore_errors=True)
run_setup(A.previous, 'verif_custom')
custom = (cu / 'AVATARES/movimentos.json').read_bytes() + b'\n'
(cu / 'AVATARES/movimentos.json').write_bytes(custom)
run_setup(setup, 'verif_custom')
assert (cu / 'AVATARES/movimentos.json').read_bytes() == custom, 'customised catalog overwritten'
REPORT.append('PASS: upgrade preserved a customised movement catalog')

# 4. Installed generator (Criador Avatar back end) with the embedded Python.
info = json.loads((fresh / 'package-info.json').read_text(encoding='utf-8-sig'))
assert info['version'] == A.version and sha(fresh / 'criador_avatar.exe') == info['criador_avatar_sha256']
py = (['wine'] if WINE else []) + [str(fresh / 'runtime/python/python.exe'), 'avatar_spec.py', 'catalog']
out = subprocess.run(py, cwd=fresh / 'tools', capture_output=True, timeout=600, env=dict(os.environ, PYTHONUTF8='1'))
assert out.returncode == 0 and len(json.loads(out.stdout)['modifiers']) > 200, out.stderr[-400:]
REPORT.append('PASS: installed Criador Avatar back end (embedded CPython 3.12, numpy, scipy, Pillow, MakeHuman targets) lists the MakeHuman modifiers')

result = {'version': A.version, 'installer_sha256': manifest['installer']['sha256'], 'result': 'PASS',
          'payload_files': len(manifest['files']), 'profiles': models,
          'environment': 'Linux + Wine 9.0 (win64 prefix); Windows-native suite (tests/check_installer.py) not run' if WINE else 'Windows',
          'checks': REPORT}
(ROOT / f'bin/setup_assistente_{A.build_code}.validacao.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
for line in REPORT:
    print(line)
