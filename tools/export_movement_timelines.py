"""One-time migration from authored glTF clips to editable JSON member timelines.
The runtime executes the exported JSON and does not read clips to create gestures.
"""
import base64,json,math
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]

def source(profile):
    d=json.loads((ROOT/'AVATARES'/profile/'modelo.gltf').read_text(encoding='utf-8'))
    raw=base64.b64decode(d['buffers'][0]['uri'].split(',')[1])
    def read(index):
        a=d['accessors'][index];v=d['bufferViews'][a['bufferView']];width={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
        return np.frombuffer(raw,dtype='<f4',offset=v.get('byteOffset',0)+a.get('byteOffset',0),count=a['count']*width).reshape(-1,width).copy()
    attrs=[d['accessors'][p['attributes']['POSITION']] for m in d['meshes'] for p in m['primitives']]
    height=max(a['max'][1] for a in attrs)-min(a['min'][1] for a in attrs)
    return d,read,height

def euler(q):
    x,y,z,w=q/np.linalg.norm(q)
    return np.degrees([math.atan2(2*(w*x+y*z),1-2*(x*x+y*y)),math.asin(np.clip(2*(w*y-z*x),-1,1)),math.atan2(2*(w*z+x*y),1-2*(y*y+z*z))])

def recipe(data,clip,definition,constant=False,face=False):
    doc,read,height=data;animation=next(a for a in doc['animations'] if a['name']==clip)
    duration=definition['duration_ms'];members=[]
    for channel in animation['channels']:
        kind=channel['target']['path'];node=doc['nodes'][channel['target']['node']];bone=node['name']
        facial=bone.startswith(('orbicularis','oculi','levator','oris','risorius','temporalis','Olho ','Íris ','Pupila ','Brilho '))
        if face and not facial:continue
        if not face and kind=='translation' and bone!='root' and definition['id'] not in ('piscar','abrir_olhos','fechar_olhos','bocejar','surpresa','triste','rir','neutro'):continue
        if not face and bone=='jaw' and definition['id'] not in ('bocejar','surpresa','rir','neutro'):continue
        if kind not in ('rotation','translation','scale'):continue
        sampler=animation['samplers'][channel['sampler']];times=read(sampler['input'])[:,0];values=read(sampler['output'])
        if kind=='rotation':
            values=np.array([euler(q) for q in values]);key='rotation_deg';epsilon=.35
        elif kind=='translation':
            values=(values-np.array(node.get('translation',[0,0,0])))/height;key='position_height';epsilon=.00015
        else:key='scale';epsilon=.003
        if constant:values=np.array([values[0],values[0]]);times=np.array([0.,1.])
        # Reduce dense baked samples while bounding component error. All extrema
        # and bends that exceed the tolerance remain authored control points.
        selected={0,len(times)-1}
        def simplify(a,b):
            if b<=a+1:return
            u=(times[a+1:b]-times[a])/(times[b]-times[a]);pred=values[a]+u[:,None]*(values[b]-values[a])
            errors=np.max(np.abs(pred-values[a+1:b]),axis=1);i=int(np.argmax(errors))+a+1
            if errors[i-a-1]>epsilon:selected.add(i);simplify(a,i);simplify(i,b)
        simplify(0,len(times)-1)
        points=[{'time_ms':round(float(times[i]/times[-1])*duration),key:[round(float(x),6) for x in values[i]]} for i in sorted(selected)]
        points=list({p['time_ms']:p for p in points}.values())
        track={'bone':bone,'start_ms':0,'duration_ms':duration}
        if len(points)==2:
            fields={'rotation_deg':('initial_rotation_deg','final_rotation_deg'),'position_height':('initial_position_height','final_position_height'),'scale':('initial_scale','final_scale')}[key]
            track[fields[0]]=points[0][key];track[fields[1]]=points[-1][key]
        else:track['keyframes']=points
        # glTF can animate both rotation and translation on one bone. Merge the
        # fields onto one member timeline with the union of their sample times.
        existing=next((m for m in members if m['bone']==bone),None)
        if existing is not None:
            # Only root and facial nodes have multiple channels in bundled data.
            def points_of(t):
                if 'keyframes' in t:return t['keyframes']
                result=[{'time_ms':0},{'time_ms':duration}]
                for k,stem in [('rotation_deg','rotation_deg'),('position_height','position_height'),('scale','scale')]:
                    if 'initial_'+stem in t:result[0][k]=t['initial_'+stem];result[1][k]=t['final_'+stem]
                return result
            a=points_of(existing);b=points_of(track);ts=sorted({p['time_ms'] for p in a+b});merged=[]
            for t in ts:
                point={'time_ms':t}
                for sequence in [a,b]:
                    fields=set(sequence[0])-{'time_ms'}
                    for field in fields:
                        point[field]=[round(float(np.interp(t,[p['time_ms'] for p in sequence],[p[field][i] for p in sequence])),6) for i in range(3)]
                merged.append(point)
            for k in list(existing):
                if k not in ('bone','start_ms','duration_ms'):del existing[k]
            existing['keyframes']=merged
        else:members.append(track)
    return dict(duration_ms=duration,transition_ms=definition['transition_ms'],return_ms=320,finish='return' if definition['mode']=='gesture' else 'hold',interpolation='linear',members=members)

def prepare_poses(catalog):
    for m in catalog['movements']:
        if m['mode']!='pose':continue
        duration=min(m['duration_ms'],1200)
        for r in [m,*m.get('profiles',{}).values()]:
            r['duration_ms']=duration;r['transition_ms']=0;r['interpolation']='smooth'
            for t in r['members']:
                t['start_ms']=0;t['duration_ms']=duration
                if 'keyframes' in t:
                    last=t.pop('keyframes')[-1]
                    for field,stem in [('rotation_deg','rotation_deg'),('position_height','position_height'),('scale','scale')]:
                        if field in last:t['initial_'+stem]='current';t['final_'+stem]=last[field]
                else:
                    for stem in ['rotation_deg','position_height','scale']:
                        if 'initial_'+stem in t:t['initial_'+stem]='current'
                if m['id']=='cruzar_bracos' and t['bone'].endswith(('.L','.R')):
                    t['duration_ms']=duration//2;t['start_ms']=0 if t['bone'].endswith('.L') else duration//2

def layout(value,level=0):
    pad='  '*level
    if isinstance(value,dict):return '{\n'+',\n'.join('  '*(level+1)+json.dumps(k,ensure_ascii=False)+': '+layout(v,level+1) for k,v in value.items())+'\n'+pad+'}'
    if isinstance(value,list):
        if value and isinstance(value[0],dict) and 'bone' in value[0]:return '[\n'+',\n'.join('  '*(level+1)+json.dumps(x,ensure_ascii=False,separators=(',',':')) for x in value)+'\n'+pad+']'
        if value and isinstance(value[0],dict):return '[\n'+',\n'.join('  '*(level+1)+layout(x,level+1) for x in value)+'\n'+pad+']'
    return json.dumps(value,ensure_ascii=False,separators=(',',':'))

def main():
    path=ROOT/'AVATARES/movimentos.json';catalog=json.loads((ROOT/'tests/fixtures/movimentos-0211.json').read_text(encoding='utf-8'))
    profiles=sorted(p.name for p in (ROOT/'AVATARES').iterdir() if (p/'modelo.gltf').exists())
    sources={p:source(p) for p in profiles}
    all_positions=set();converted=[]
    for m in catalog['movements']:
        clip=m.get('clip');constant=False;face=m['mode']=='smile'
        if not clip:
            clip='idle_smile' if face else 'idle_right_hand_up' if m['mode']=='raise_right' else 'idle';constant=True
            if m['mode'] not in ('smile','raise_right'):m['duration_ms']=320
        original_mode=m['mode'];m['mode']='gesture' if original_mode=='gesture' else 'pose'
        base=recipe(sources['professor'],clip,m,constant,face)
        if not base['members']:raise RuntimeError(m['id'])
        m.update(base);m.pop('clip',None);m.pop('talking_clip',None)
        m['profiles']={}
        for profile in profiles:
            if profile=='professor':continue
            r=recipe(sources[profile],clip,m,constant,face)
            if r['members']!=m['members']:m['profiles'][profile]=r
        if not m['profiles']:del m['profiles']
        for r in [m,*m.get('profiles',{}).values()]:
            for track in r['members']:
                if 'initial_position_height' in track or ('keyframes' in track and 'position_height' in track['keyframes'][0]):all_positions.add(track['bone'])
        converted.append(m)
    catalog['version']=2;catalog['movements']=converted
    prepare_poses(catalog)
    path.write_text(layout(catalog)+'\n',encoding='utf-8')
    collisions=ROOT/'AVATARES/colisoes.json';c=json.loads(collisions.read_text(encoding='utf-8'));c['translatable_members']=sorted(all_positions)
    collisions.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Exported',len(converted),'JSON movements for',len(profiles),'avatars;',path.stat().st_size,'bytes')

if __name__=='__main__':main()
