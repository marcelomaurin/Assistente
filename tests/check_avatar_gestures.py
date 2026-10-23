"""Validate exported gesture directions, hand articulation and persistent poses."""
import base64
import json
import sys
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from game_avatar import GESTURE_CLIPS

def validate(path):
    doc=json.loads(path.read_text(encoding='utf8'))
    binary=base64.b64decode(doc['buffers'][0]['uri'].split(',')[1])
    names={n['name']:i for i,n in enumerate(doc['nodes'])}
    animations={a['name']:a for a in doc['animations']}
    assert set(GESTURE_CLIPS)<=animations.keys(),(path,'Missing real gesture clips')
    parent={child:i for i,n in enumerate(doc['nodes']) for child in n.get('children',[])}
    def read(i):
        a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
        return np.frombuffer(binary,dtype='<f4',count=a['count']*width,
            offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width)
    def sample(clip,bone,t,path='rotation'):
        a=animations[clip]
        c=next(c for c in a['channels'] if c['target']==dict(node=names[bone],path=path))
        s=a['samplers'][c['sampler']];ts=read(s['input'])[:,0];vs=read(s['output'])
        i=min(len(ts)-2,max(0,np.searchsorted(ts,t,side='right')-1))
        u=np.clip((t-ts[i])/(ts[i+1]-ts[i]),0,1);v=(1-u)*vs[i]+u*vs[i+1]
        return v/np.linalg.norm(v) if path=='rotation' else v
    def pose(clip,t):
        local={};world={}
        for i,n in enumerate(doc['nodes']):
            q=np.array(n.get('rotation',[0,0,0,1]),dtype=float)
            tr=np.array(n.get('translation',[0,0,0]),dtype=float)
            if n['name'] in names:
                for p in ('rotation','translation'):
                    if any(c['target']==dict(node=i,path=p) for c in animations[clip]['channels']):
                        if p=='rotation':q=sample(clip,n['name'],t,p)
                        else:tr=sample(clip,n['name'],t,p)
            x,y,z,w=q;m=np.eye(4)
            m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                         [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                         [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
            m[:3,3]=tr;local[i]=m
        def visit(i):
            if i not in world:world[i]=(visit(parent[i]) if i in parent else np.eye(4))@local[i]
            return world[i]
        return {n:visit(i) for n,i in names.items()}
    idle=pose('idle',0);up=pose('levantar_mao_esquerda',1.2)
    height=idle['head'][1,3]
    assert up['wrist.L'][1,3]>up['head'][1,3],(path,'Left hand did not reach overhead')
    assert abs(up['wrist.R'][1,3]-idle['wrist.R'][1,3])<height*.03,(path,'Wrong hand raised')
    foot=pose('levantar_pe_direito',1.2)
    assert foot['foot.R'][1,3]>idle['foot.R'][1,3]+height*.05,(path,'Right foot not lifted')
    assert abs(foot['foot.L'][1,3]-idle['foot.L'][1,3])<height*.03,(path,'Support foot lifted')
    for clip,component in [('concordar',0),('negar',1)]:
        assert abs(sample(clip,'head',.62)[component])>.04,(path,clip,'Head did not move')
        assert abs(sample(clip,'head',.62)[1-component])<.002,(path,clip,'Wrong head axis')
    left=pose('olhar_para_tras_esquerda',1.2);right=pose('olhar_para_tras_direita',1.2)
    assert left['head'][2,2]<0 and right['head'][2,2]<0,(path,'Head is not looking behind')
    assert left['head'][0,2]*right['head'][0,2]<0,(path,'Back turns are not mirrored')
    for side,label in [('L','esquerda'),('R','direita')]:
        closed=sample('fechar_mao_'+label,'finger3-2.'+side,1.2)
        opened=sample('abrir_mao_'+label,'finger3-2.'+side,1.2)
        assert abs(np.dot(closed,opened))<.9,(path,'Fist and open hand indistinguishable',side)
    crossed=pose('cruzar_bracos',1.2)
    assert crossed['wrist.L'][0,3]<crossed['wrist.R'][0,3],(path,'Forearms do not cross the chest')
    assert min(crossed['wrist.L'][2,3],crossed['wrist.R'][2,3])>idle['spine01'][2,3]+height*.05,(path,'Crossed hands are inside/behind the torso')
    for side in ('L','R'):
        assert crossed['wrist.'+side][1,3]>idle['wrist.'+side][1,3]+height*.05,(path,'Crossed hand stayed at rest')
    catalog=json.loads((ROOT/'AVATARES/movimentos.json').read_text(encoding='utf-8'))
    for movement in catalog['movements']:
        for key in ('clip','talking_clip'):
            assert not movement.get(key) or movement[key] in animations,(path,'Catalog references absent animation',movement['id'],key)
    thumb=pose('positivo',1.2)
    direction=thumb['finger1-3.R'][:3,3]-thumb['finger1-1.R'][:3,3]
    assert direction[1]>abs(direction[0]),(path,'Thumb is not pointing up',direction)
    assert sample('bocejar','jaw',1.6)[0]>.15,(path,'Yawn jaw is shut')
    if path.parent.name=='ze_gotinha':
        assert sample('fechar_olhos','Olho L',1.2,'scale')[1]<.1
        assert sample('abrir_olhos','Olho L',1.2,'scale')[1]>.95
    else:
        face=[n for n in names if n.startswith(('orbicularis','oculi'))]
        assert max(np.linalg.norm(sample('fechar_olhos',n,1.2,'translation')-
                                  sample('abrir_olhos',n,1.2,'translation')) for n in face)>.001
    for clip in GESTURE_CLIPS:
        for channel in animations[clip]['channels']:
            if channel['target']['path']!='rotation':continue
            values=read(animations[clip]['samplers'][channel['sampler']]['output'])
            assert np.isfinite(values).all(),(path,clip,'Nonfinite rotation')
            assert np.max(np.abs(np.linalg.norm(values,axis=1)-1))<1e-5,(path,clip,'Unnormalized rotation')
    print('PASS:',path.parent.name,f'{len(GESTURE_CLIPS)} clips; complete catalog, crossed arms, handedness, head, waist, foot, fists, thumb, yawn and eyelids',flush=True)

if __name__=='__main__':
    profiles=sys.argv[1:] or sorted(p.name for p in (ROOT/'AVATARES').iterdir() if p.is_dir())
    for profile in profiles:validate(ROOT/'AVATARES'/profile/'modelo.gltf')
