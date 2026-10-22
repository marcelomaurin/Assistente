"""Check actual exported skin deformation, handedness, foot contact and loop seams.
Requires numpy (offline authoring dependency); no renderer or network needed.
"""
import base64
import json
import sys
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]/'AVATARES'

paths=[ROOT/sys.argv[1]/'modelo.gltf'] if len(sys.argv)>1 else sorted(ROOT.glob('*/modelo.gltf'))
for path in paths:
    if path.parent.name == 'ze_gotinha':
        from check_ze_gotinha import validate
        validate(path)
        continue
    d=json.loads(path.read_text(encoding='utf-8'));binary=base64.b64decode(d['buffers'][0]['uri'].split(',')[1])
    def read(index):
        a=d['accessors'][index];width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        offset=d['bufferViews'][a['bufferView']].get('byteOffset',0)+a.get('byteOffset',0)
        return np.frombuffer(binary,dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']],count=a['count']*width,offset=offset).reshape(-1,width)
    parent={child:i for i,n in enumerate(d['nodes']) for child in n.get('children',[])}
    names={n['name']:i for i,n in enumerate(d['nodes'])}
    skin=d['skins'][0];inverse=read(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    def pose(clip=None,t=0):
        translations=[np.array(n.get('translation',[0,0,0]),dtype=float) for n in d['nodes']]
        rotations=[np.array(n.get('rotation',[0,0,0,1]),dtype=float) for n in d['nodes']]
        if clip:
            animation=next(a for a in d['animations'] if a['name']==clip)
            for channel in animation['channels']:
                p=channel['target']['path'];node=channel['target']['node']
                if p not in ('translation','rotation'):continue
                sampler=animation['samplers'][channel['sampler']];times=read(sampler['input'])[:,0];values=read(sampler['output'])
                i=min(len(times)-2,max(0,np.searchsorted(times,t,side='right')-1));u=np.clip((t-times[i])/(times[i+1]-times[i]),0,1)
                v=(1-u)*values[i]+u*values[i+1]
                if p=='rotation':rotations[node]=v/np.linalg.norm(v)
                else:translations[node]=v
        local=[]
        for tr,q in zip(translations,rotations):
            x,y,z,w=q;m=np.eye(4)
            m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                      [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                      [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
            m[:3,3]=tr;local.append(m)
        world={}
        def visit(i):
            if i not in world:world[i]=(visit(parent[i]) if i in parent else np.eye(4))@local[i]
            return world[i]
        for i in range(len(local)):visit(i)
        return world
    rest=pose()
    assert np.max(np.abs(np.array([rest[i] for i in skin['joints']])@inverse-np.eye(4)))<1e-5,'Bind matrices do not preserve rest geometry'
    height=d['accessors'][d['meshes'][0]['primitives'][0]['attributes']['POSITION']]['max'][1]
    idle=pose('idle',.3);wave=pose('wave',1.1);up=pose('idle_right_hand_up',.6)
    right=names['wrist.R'];left=names['wrist.L'];head=names['head']
    assert wave[right][1,3]>idle[right][1,3]+height*.2,'Wave failed to raise right hand'
    assert up[right][1,3]>up[head][1,3]+height*.04,'Held hand is not raised'
    assert abs(up[left][1,3]-idle[left][1,3])<height*.03,'Wrong hand moved'
    # Overhead reach must lift the shoulder girdle. The old clips rotated only
    # the upper-arm bone below the deltoid, leaving a pinched/displaced shoulder.
    upper=names['upperarm01.R'];shoulder=names['shoulder01.R']
    for clip,t in (('wave',1.1),('idle_right_hand_up',.6),('talking_smile_right_hand_up',.6)):
        overhead=pose(clip,t)
        assert overhead[upper][1,3]>idle[upper][1,3]+height*.02,'Overhead shoulder remained fixed: '+clip
        assert np.linalg.norm(overhead[upper][:3,3]-idle[upper][:3,3])<height*.10,'Shoulder left anatomical region: '+clip
        assert np.linalg.norm(overhead[shoulder][:3,3]-idle[shoulder][:3,3])<height*.04,'Clavicle moved excessively: '+clip

    # Inspect the exported palm basis on BOTH mirrored hands. Checking only
    # wrist positions misses a clap that hits the back of the other hand.
    for clip in ('applause','applause_smile','applause_talking_smile'):
        clap=pose(clip,1.1)
        for side,sign in (('R',1),('L',-1)):
            origin=clap[names['wrist.'+side]][:3,3]
            forward=clap[names['finger3-3.'+side]][:3,3]-origin
            thumb=clap[names['finger1-1.'+side]][:3,3]-origin
            normal=np.cross(thumb,forward) if side=='R' else np.cross(forward,thumb)
            normal/=np.linalg.norm(normal)
            assert normal[0]*sign>.94,'Clap palm facing the wrong way: '+side
    # Evaluate exported four-weight skinning, not just animated joint metadata.
    prim=next(m['primitives'][0] for m in d['meshes'] if m['name']=='Vestuário deformável')
    at=prim['attributes'];p=read(at['POSITION']);j=read(at['JOINTS_0']).astype(int);w=read(at['WEIGHTS_0'])
    hp=np.column_stack([p,np.ones(len(p))])
    def deform(world):
        matrices=np.array([world[i] for i in skin['joints']])@inverse
        result=np.zeros_like(hp)
        for influence in range(4):result+=np.einsum('nij,nj->ni',matrices[j[:,influence]],hp)*w[:,influence,None]
        return result[:,:3]
    assert np.max(np.linalg.norm(deform(wave)-deform(idle),axis=1))>height*.06,'Clothing did not follow skeleton'
    # A short-sleeved shirt moves less than a hand. Check the continuous skin too.
    at=d['meshes'][0]['primitives'][0]['attributes'];p=read(at['POSITION']);j=read(at['JOINTS_0']).astype(int);w=read(at['WEIGHTS_0'])
    hp=np.column_stack([p,np.ones(len(p))])
    assert np.max(np.linalg.norm(deform(wave)-deform(idle),axis=1))>height*.2,'Hand skin did not follow skeleton'
    # Stance ankle height should stay near its rest plane; swing must clear it.
    contact=[];swing=[]
    for t in np.linspace(0,1.2,49):
        world=pose('walk',float(t));u=(t/1.2)%1
        (contact if u<.6 else swing).append(world[names['foot.L']][1,3])
    assert max(contact)-min(contact)<height*.035,'Excessive foot contact drift'
    assert max(swing)>min(contact)+height*.01,'No swing clearance'
    for clip in ('idle','walk','talking','wave','applause'):
        animation=next(a for a in d['animations'] if a['name']==clip)
        duration=max(read(s['input'])[-1,0] for s in animation['samplers'])
        first,last=pose(clip,0),pose(clip,float(duration))
        assert max(np.max(np.abs(first[i]-last[i])) for i in skin['joints'])<.015,'Loop pose discontinuity: '+clip
    max_speed=0.
    for animation in d['animations']:
        for channel in animation['channels']:
            if channel['target']['path']!='rotation':continue
            sampler=animation['samplers'][channel['sampler']];times=read(sampler['input'])[:,0]
            q=read(sampler['output']).astype(float);q/=np.linalg.norm(q,axis=1,keepdims=True)
            dots=np.clip(np.abs((q[:-1]*q[1:]).sum(1)),0,1)
            speed=np.degrees(2*np.arccos(dots))/np.diff(times)
            maximum=float(speed.max());max_speed=max(max_speed,maximum)
            assert maximum<900,'Abrupt joint rotation: '+animation['name']+' / '+d['nodes'][channel['target']['node']]['name']
    # Check skin displacement in head/wrist coordinates: head or arm motion
    # alone must not make a stationary face/finger pass these assertions.
    def local_skin(clip,t,bone):
        world=pose(clip,t)
        points=deform(world)
        return (np.column_stack([points,np.ones(len(points))])@np.linalg.inv(world[names[bone]]).T)[:,:3]
    talk=next(a for a in d['animations'] if a['name']=='talking')
    channel=next(c for c in talk['channels'] if c['target']==dict(node=names['jaw'],path='rotation'))
    sampler=talk['samplers'][channel['sampler']];qs=read(sampler['output']);ts=read(sampler['input'])[:,0]
    closed=float(ts[np.argmin(qs[:,0])]);opened=float(ts[np.argmax(qs[:,0])])
    assert qs[:,0].max()>.06 and qs[:,0].min()>=0,'Jaw must open down/back, with visible range'
    jaw_index=skin['joints'].index(names['jaw'])
    chin=((j==jaw_index)*w).sum(1)>.5
    mouth0=local_skin('talking',closed,'head');mouth1=local_skin('talking',opened,'head')
    assert (mouth1[chin,1]-mouth0[chin,1]).min()<-height*.004,'Jaw skin did not open downward'
    # Verify tooth attachment from exported skin, separately from lip motion.
    teeth=next(m['primitives'][0]['attributes'] for m in d['meshes'] if m['name']=='Dentes')
    tp=read(teeth['POSITION']);tj=read(teeth['JOINTS_0']).astype(int);tw=read(teeth['WEIGHTS_0'])
    th=np.column_stack([tp,np.ones(len(tp))])
    def tooth_local(t,bone):
        world=pose('talking',t);matrices=np.array([world[i] for i in skin['joints']])@inverse
        points=sum(np.einsum('nij,nj->ni',matrices[tj[:,k]],th)*tw[:,k,None] for k in range(4))
        return points@np.linalg.inv(world[names[bone]]).T
    for bone in ('head','jaw'):
        pure=((tj==skin['joints'].index(names[bone]))*tw).sum(1)>.999
        assert pure.sum()>50,'Missing teeth attached to '+bone
        assert np.max(np.abs(tooth_local(opened,bone)[pure]-tooth_local(closed,bone)[pure]))<1e-5,'Teeth detached from '+bone
    blink0=local_skin('idle',4.,'head');blink1=local_skin('idle',4.32,'head')
    for side in ('L','R'):
        eyelid_index=skin['joints'].index(names['orbicularis03.'+side])
        eyelid=((j==eyelid_index)*w).sum(1)>.5
        assert np.median(blink1[eyelid,1]-blink0[eyelid,1])<-height*.002,'Upper eyelid did not close: '+side
        finger_indices=[skin['joints'].index(names[n]) for n in names if n.startswith('finger') and n.endswith('.'+side)]
        fingers=(np.isin(j,finger_indices)*w).sum(1)>.7
        first=local_skin('talking',.15,'wrist.'+side);second=local_skin('talking',.75,'wrist.'+side)
        assert np.max(np.linalg.norm(second[fingers]-first[fingers],axis=1))>height*.002,'Finger skin remained rigid: '+side
        eye0=pose('idle',1.)[names['eye.'+side]][:3,:3]
        eye1=pose('idle',3.)[names['eye.'+side]][:3,:3]
        head0=pose('idle',1.)[head][:3,:3];head1=pose('idle',3.)[head][:3,:3]
        assert np.max(np.abs(head0.T@eye0-head1.T@eye1))>.03,'No eye gaze independent of head'
    eye_mesh=next(m for m in d['meshes'] if m['name'].startswith('Olhos:'))
    assert d['materials'][eye_mesh['primitives'][0]['material']]['alphaMode']=='MASK','Opaque cornea hides iris/pupil'
    # No simultaneous morph deformation in engines which also support morphs.
    for animation in d['animations']:
        for c in animation['channels']:
            if c['target']['path']=='weights':
                assert not np.any(read(animation['samplers'][c['sampler']]['output'])),'Double facial deformation'
    print('PASS:',path.parent.name,'jaw/chin skin, bilateral eyelids, finger flex independent of wrist, coordinated gaze, transparent cornea')
    print('PASS:',path.parent.name,'bind pose, overhead shoulder support, hand/palm direction, skin deformation, gait contact/clearance and loop seams')
    print('Maximum sampled joint speed, deg/s:',round(max_speed,1))
