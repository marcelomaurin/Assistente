"""Native CGE facial/finger regressions, controlled fixtures + real playback.
Build professor_articulation_smoke first. numpy and Pillow are authoring tools.
"""
from pathlib import Path
import base64
import json
import math
import subprocess
import sys
import time
import numpy as np
from PIL import Image,ImageDraw

root=Path(__file__).resolve().parents[1]
out=root/'build/professor/articulation-validation'
out.mkdir(parents=True,exist_ok=True)
profiles=sys.argv[1:] or ['engenheiro','dona_de_casa','bebe','robo']
report=[]
for profile in profiles:
    model=root/'AVATARES'/profile/'modelo.gltf'
    source=json.loads(model.read_text(encoding='utf-8'))
    binary=base64.b64decode(source['buffers'][0]['uri'].split(',')[1])
    def read(i):
        a=source['accessors'][i];v=source['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        return np.frombuffer(binary,dtype='<f4',count=a['count']*width,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width)
    def sample(animation,channel,t):
        s=animation['samplers'][channel['sampler']];ts=read(s['input'])[:,0];vs=read(s['output'])
        if channel['target']['path']=='weights':vs=vs.reshape(len(ts),-1)
        i=min(len(ts)-2,max(0,np.searchsorted(ts,t,side='right')-1))
        u=np.clip((t-ts[i])/(ts[i+1]-ts[i]),0,1);v=(1-u)*vs[i]+u*vs[i+1]
        return v/np.linalg.norm(v) if channel['target']['path']=='rotation' else v
    names={n['name']:i for i,n in enumerate(source['nodes'])}
    skin=source['skins'][0];inverse=read(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    rest={source['nodes'][n]['name']:np.linalg.inv(m)[:3,3] for n,m in zip(skin['joints'],inverse)}
    height=source['accessors'][source['meshes'][0]['primitives'][0]['attributes']['POSITION']]['max'][1]
    talk=next(a for a in source['animations'] if a['name']=='talking')
    jaw=next(c for c in talk['channels'] if c['target']==dict(node=names['jaw'],path='rotation'))
    s=talk['samplers'][jaw['sampler']];q=read(s['output']);ts=read(s['input'])[:,0]
    mouth_times=[float(ts[np.argmin(q[:,0])]),float(ts[np.argmax(q[:,0])])]
    eyes=(rest['eye.L']+rest['eye.R'])/2
    eye_spacing=float(np.linalg.norm(rest['eye.L']-rest['eye.R']))
    # Head proportions vary strongly with age: body-height zoom can place
    # the camera inside the baby's face and conceal the actual eyelids.
    cases=[('mouth','talking',mouth_times,eyes+[0,-eye_spacing*.73,0],eye_spacing*6.2),
           ('blink','idle',[4.,4.32],eyes,eye_spacing*4.),
           ('gaze','idle',[1.,3.],eyes,eye_spacing*4.)]
    if profile=='engenheiro':cases.append(('fingers','talking',[.15,.75],np.array([-.37,1.91,.27]),.5))
    for name,clip,times,focus,distance in cases:
        doc=json.loads(json.dumps(source))
        # Hold everything outside the part under inspection still. Pixel changes
        # must come from the mouth, eyelids, eye globes or phalanges themselves.
        animation=next(a for a in doc['animations'] if a['name']==clip)
        def is_active(c):
            bone=doc['nodes'][c['target']['node']]['name']
            return (name=='mouth' and (bone=='jaw' or bone.startswith(('levator','oris','risorius','temporalis')))
                    or name=='blink' and bone.startswith('orbicularis')
                    or name=='gaze' and bone.startswith('eye.')
                    or name=='fingers' and bone.startswith('finger'))
        frozen=next(a for a in doc['animations'] if a['name']==('wave' if name=='fingers' else clip))
        for c in animation['channels']:
            node=doc['nodes'][c['target']['node']];path=c['target']['path']
            if not is_active(c) and path!='weights':
                fixed=next(fc for fc in frozen['channels'] if fc['target']==c['target'])
                node[path]=sample(frozen,fixed,1.1 if name=='fingers' else 0.).tolist()
        # LoadModel starts idle before the first capture: freeze unrelated
        # tracks in that initial animation too, not only the inspected clip.
        for a in doc['animations']:a['channels']=[c for c in a['channels'] if is_active(c)]
        for image in doc['images']:image['uri']=(model.parent/image['uri']).as_uri()
        folder=out/profile/name;folder.mkdir(parents=True,exist_ok=True)
        fixture=folder/'fixture.gltf';fixture.write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
        args=[str(root/'build/professor/professor_articulation_smoke.exe'),str(fixture),clip,
              *map(str,times),*map(str,focus),str(distance),'3.9' if name=='blink' else '0',str(folder)]
        started=time.time()
        result=subprocess.run(args,cwd=root,capture_output=True,timeout=120)
        log=(result.stdout+result.stderr).decode(errors='replace')
        assert result.returncode==0,(profile,name,result.returncode,log)
        assert all((folder/f'{i:02}.png').stat().st_mtime>=started-2 for i in range(10)),'Stale native captures'
        frames=[Image.open(folder/f'{i:02}.png').convert('RGB') for i in range(10)]
        arrays=[np.asarray(im).astype(float) for im in frames]
        changed=int((np.abs(arrays[0]-arrays[1]).max(2)>12).sum())
        assert changed>60,(profile,name,'No visible independent articulation',changed)
        live=max(int((np.abs(a-arrays[2]).max(2)>12).sum()) for a in arrays[3:])
        assert live>60,(profile,name,'Native playback stalled',live)
        w,h=frames[0].size
        sheet=Image.new('RGB',(w*2,h+24),'white');draw=ImageDraw.Draw(sheet)
        for i,im in enumerate(frames[:2]):
            sheet.paste(im,(i*w,24));draw.text((i*w+10,5),f'{profile} / {name} / pose {i}',fill='black')
        sheet.save(folder/'comparison.png')
        frames[2].save(folder/'playback.gif',save_all=True,append_images=frames[3:],duration=120,loop=0)
        record={'profile':profile,'part':name,'changed_pixels':changed,'live_changed_pixels':live,'elapsed_seconds':round(time.time()-started,2),'result':'PASS'}
        report.append(record);print(json.dumps(record),flush=True)
        (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS: native articulation comparisons and progressing playback')
