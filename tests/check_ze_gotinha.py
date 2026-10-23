"""Validate the mascot's closed body, reference proportions and skeletal face."""
import base64
import json
from pathlib import Path
import numpy as np


def validate(path):
    path=Path(path);doc=json.loads(path.read_text(encoding='utf-8'))
    raw=base64.b64decode(doc['buffers'][0]['uri'].split(',')[1])
    def read(index):
        a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        return np.frombuffer(raw,dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']],
            count=a['count']*width,offset=view.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,width)
    nodes=doc['nodes'];names={n['name']:i for i,n in enumerate(nodes)}
    parent={child:i for i,n in enumerate(nodes) for child in n.get('children',[])}
    def pose(clip=None,t=0):
        tr=[np.array(n.get('translation',[0,0,0]),float) for n in nodes]
        rot=[np.array(n.get('rotation',[0,0,0,1]),float) for n in nodes]
        scale=[np.array(n.get('scale',[1,1,1]),float) for n in nodes]
        if clip:
            for c in next(a for a in doc['animations'] if a['name']==clip)['channels']:
                s=next(a for a in doc['animations'] if a['name']==clip)['samplers'][c['sampler']]
                ts=read(s['input'])[:,0];vs=read(s['output']);i=max(0,min(len(ts)-2,np.searchsorted(ts,t,side='right')-1))
                u=np.clip((t-ts[i])/(ts[i+1]-ts[i]),0,1);v=vs[i]*(1-u)+vs[i+1]*u
                node=c['target']['node'];p=c['target']['path']
                if p=='rotation':rot[node]=v/np.linalg.norm(v)
                elif p=='translation':tr[node]=v
                elif p=='scale':scale[node]=v
        world={}
        def visit(i):
            if i not in world:
                x,y,z,w=rot[i];m=np.eye(4)
                m[:3,:3]=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                    [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                    [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])@np.diag(scale[i])
                m[:3,3]=tr[i];world[i]=(visit(parent[i]) if i in parent else np.eye(4))@m
            return world[i]
        for i in range(len(nodes)):visit(i)
        return world
    skin=doc['skins'][0];rest=pose();inverse=read(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    assert np.max(np.abs(np.array([rest[i] for i in skin['joints']])@inverse-np.eye(4)))<1e-5
    body=next(m for m in doc['meshes'] if m['name']=='Corpo arredondado contínuo')['primitives'][0]
    attrs=body['attributes'];points=read(attrs['POSITION']);tri=read(body['indices']).reshape(-1,3)
    edges=np.sort(np.concatenate([tri[:,[0,1]],tri[:,[1,2]],tri[:,[2,0]]]),axis=1)
    _,counts=np.unique(edges,axis=0,return_counts=True)
    assert np.all(counts==2),'Mascot body must be closed, without open wrists/neck or nonmanifold edges'
    parents=list(range(len(points)))
    def find(i):
        while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
        return i
    for a,b,c in tri:parents[find(b)]=find(a);parents[find(c)]=find(a)
    assert len({find(int(i)) for i in tri.reshape(-1)})==1,'Disconnected body or floating fingers'
    assert not any(m['name'] in ('Vestuário deformável','Calçados','Dentes') for m in doc['meshes'])
    head=next(m for m in doc['meshes'] if m['name']=='Cabeça em gota com ponta curva')['primitives'][0]
    hp=read(head['attributes']['POSITION']);size=np.ptp(hp,axis=0)
    assert .43<size[0]<.50 and .58<size[1]<.65 and size[1]>size[0]
    assert hp[np.argmax(hp[:,1]),0]>.08,'Missing curved drop apex'
    clips={a['name'] for a in doc['animations']}
    assert len(clips)==65 and {'idle','wave','walk','talking','applause'}<=clips
    def skinned(clip,t):
        world=pose(clip,t);m=np.array([world[i] for i in skin['joints']])@inverse
        js=read(attrs['JOINTS_0']).astype(int);ws=read(attrs['WEIGHTS_0']);p=np.column_stack([points,np.ones(len(points))])
        out=sum(np.einsum('nij,nj->ni',m[js[:,k]],p)*ws[:,k,None] for k in range(4))
        return out,world,js,ws
    idle,_,_,_=skinned('idle',.3);wave,_,_,_=skinned('wave',1.1)
    assert np.max(np.linalg.norm(wave[:,:3]-idle[:,:3],axis=1))>.25,'Wave failed to deform the body'
    a=pose('idle',4.0);b=pose('idle',4.32)
    for side in ('L','R'):
        node=names['Olho '+side]
        assert np.linalg.norm(b[node][:3,1])<np.linalg.norm(a[node][:3,1])*.15,'Blink failed'
        p,w,js,ws=skinned('talking',.15);q,v,_,_=skinned('talking',.75)
        ids=[k for k,n in enumerate(skin['joints']) if nodes[n]['name'].startswith('finger') and nodes[n]['name'].endswith('.'+side)]
        selected=(np.isin(js,ids)*ws).sum(1)>.7
        assert selected.any(),'Missing finger skin'
        local0=p@np.linalg.inv(w[names['wrist.'+side]]).T
        local1=q@np.linalg.inv(v[names['wrist.'+side]]).T
        assert np.max(np.linalg.norm(local1[selected,:3]-local0[selected,:3],axis=1))>.001,'Rigid fingers'
    mouth=doc['meshes'][nodes[names['Boca articulada']]['mesh']]['primitives'][0]['attributes']
    mp=read(mouth['POSITION']);mj=read(mouth['JOINTS_0']).astype(int);mw=read(mouth['WEIGHTS_0'])
    def mouth_pose(t):
        world=pose('talking',t);matrices=np.array([world[i] for i in skin['joints']])@inverse
        points=np.column_stack([mp,np.ones(len(mp))])
        p=sum(np.einsum('nij,nj->ni',matrices[mj[:,k]],points)*mw[:,k,None] for k in range(4))
        return p@np.linalg.inv(world[names['head']]).T
    first=mouth_pose(0);other=mouth_pose(.15)
    assert np.max(np.abs(first[0::2]-other[0::2]))<1e-5,'Upper lip must stay fixed to head'
    assert np.max(np.abs(first[1::2]-other[1::2]))>.0005,'Lower lip does not animate'
    for clip in ('idle','walk','talking','wave','applause'):
        animation=next(a for a in doc['animations'] if a['name']==clip)
        end=max(read(s['input'])[-1,0] for s in animation['samplers'])
        first,last=pose(clip,0),pose(clip,float(end))
        assert max(np.max(np.abs(first[i]-last[i])) for i in skin['joints'])<.015,'Loop seam: '+clip
    for image in doc['images']:assert (path.parent/image['uri']).is_file()
    print('PASS: ze_gotinha closed connected mascot body, drop proportions, bind skin, wave, fingers, blink, mouth, 65 clips and loop seams')


if __name__=='__main__':
    import sys
    validate(Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]/'AVATARES/ze_gotinha/modelo.gltf')
