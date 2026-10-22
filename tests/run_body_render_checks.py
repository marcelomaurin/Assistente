"""Render dressed short-sleeved profiles and a neutral adult body-only fixture.

Build professor_animation_smoke first. Captures are stored under build/professor.
No microphone, network, paid provider, or image-generation service is used.
"""
from pathlib import Path
import json
import shutil
import subprocess
import time

root=Path(__file__).resolve().parents[1]
out=root/'build/professor'
review=out/'body-validation'
review.mkdir(exist_ok=True)
profile=root/'AVATARES/engenheiro/modelo.gltf'
doc=json.loads(profile.read_text(encoding='utf-8'))
# Render only the body; garment/accessory nodes remain absent from the scene.
for node in doc['nodes']:
    if node.get('mesh',0)!=0:
        del node['mesh']
for mat in doc['materials']:
    mat.clear()
    mat.update(name='Mannequin validation',doubleSided=True,
               pbrMetallicRoughness={'baseColorFactor':[0.65,0.7,0.75,1],'roughnessFactor':0.8})
for img in doc['images']:
    img['uri']=(profile.parent/img['uri']).as_uri()
fixture=review/'body-without-clothing.gltf'
fixture.write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
log=[]
for name,model in [('engenheiro',profile),('dona_de_casa',root/'AVATARES/dona_de_casa/modelo.gltf'),
                   ('body-without-clothing',fixture)]:
    started=time.time()
    result=subprocess.run([str(out/'professor_animation_smoke.exe'),str(model)],cwd=root,
                          capture_output=True,timeout=90)
    text=(result.stdout+result.stderr).decode('utf-8',errors='replace')
    log.append(f'{name}: exit {result.returncode}, {time.time()-started:.2f}s\n{text}')
    if result.returncode:
        raise RuntimeError(log[-1])
    files=list((out/'animation-smoke').glob('*.png'))
    assert len(files)==13 and all(p.stat().st_mtime>=started-2 for p in files), 'Missing or stale pose capture'
    shutil.copytree(out/'animation-smoke',review/name,dirs_exist_ok=True)
    print(log[-1],flush=True)
(review/'result.txt').write_text('\n'.join(log),encoding='utf-8')
