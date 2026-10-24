"""Offline calibration of JSON arm paths against the same capsule rig as the player.
Requires numpy/scipy only for authoring; the installed applications read the JSON.
"""
import json, math, copy
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation
from scipy.optimize import minimize
ROOT=Path(__file__).resolve().parents[1]

def segment_distance(p,q,r,s):
    d1=q-p;d2=s-r;v=p-r
    a=np.sum(d1*d1,axis=1);e=np.sum(d2*d2,axis=1);f=np.sum(d2*v,axis=1)
    c=np.sum(d1*v,axis=1);b=np.sum(d1*d2,axis=1);den=a*e-b*b
    u=np.divide(b*f-c*e,den,out=np.zeros_like(a),where=den>1e-16);u=np.clip(u,0,1)
    u=np.where(e<1e-16,np.clip(np.divide(-c,a,out=np.zeros_like(a),where=a>1e-16),0,1),u)
    t=np.divide(b*u+f,e,out=np.zeros_like(a),where=e>1e-16)
    u=np.where(t<0,np.clip(np.divide(-c,a,out=np.zeros_like(a),where=a>1e-16),0,1),u)
    u=np.where(t>1,np.clip(np.divide(b-c,a,out=np.zeros_like(a),where=a>1e-16),0,1),u)
    t=np.clip(t,0,1)
    return np.linalg.norm(p+d1*u[:,None]-r-d2*t[:,None],axis=1)

class Rig:
    def __init__(self,profile):
        d=json.loads((ROOT/'AVATARES'/profile/'modelo.gltf').read_text(encoding='utf-8'));self.nodes=d['nodes'];ns=self.nodes
        self.names={n.get('name'):i for i,n in enumerate(ns)};self.parents={c:i for i,n in enumerate(ns) for c in n.get('children',[])}
        attrs=[d['accessors'][p['attributes']['POSITION']] for m in d['meshes'] for p in m['primitives']]
        self.height=max(a['max'][1] for a in attrs)-min(a['min'][1] for a in attrs)
        self.restrot=Rotation.from_quat([n.get('rotation',[0,0,0,1]) for n in ns]).as_matrix()
        self.restpos=np.array([n.get('translation',[0,0,0]) for n in ns])/self.height
        c=json.loads((ROOT/'AVATARES/colisoes.json').read_text(encoding='utf-8'));self.shapes=c['bodies'];self.margin=c['margin_height']
        self.ia=np.array([self.names[b['start_bone']] for b in self.shapes]);self.ib=np.array([self.names[b.get('end_bone',b['start_bone'])] for b in self.shapes]);self.radii=np.array([b['radius_height'] for b in self.shapes])
        self.sf=np.array([b.get('start_fraction',0) for b in self.shapes])[:,None];self.ef=np.array([b.get('end_fraction',1) for b in self.shapes])[:,None]
        self.so=np.array([b.get('start_offset_height',[0,0,0]) for b in self.shapes]);self.eo=np.array([b.get('end_offset_height',[0,0,0]) for b in self.shapes])
        ignore={tuple(sorted(p)) for p in c.get('ignored_pairs',[])};pairs=[(i,j) for i in range(len(self.shapes)) for j in range(i+1,len(self.shapes)) if tuple(sorted([self.shapes[i]['id'],self.shapes[j]['id']])) not in ignore]
        self.pi=np.array([p[0] for p in pairs]);self.pj=np.array([p[1] for p in pairs])
        needed=set(self.ia)|set(self.ib)
        for i in list(needed):
            while i in self.parents:i=self.parents[i];needed.add(i)
        self.order=[]
        def visit(i):
            if i in self.order:return
            if i in self.parents:visit(self.parents[i])
            self.order.append(i)
        for i in sorted(needed):visit(i)
        self.vars=[self.names[b+s] for s in ['.L','.R'] for b in ['upperarm01','lowerarm01','wrist']]
    def gaps(self,angles,pos):
        local=self.restrot@Rotation.from_euler('xyz',angles,degrees=True).as_matrix()
        wr=np.empty_like(local);wp=np.empty_like(pos)
        for i in self.order:
            p=self.parents.get(i)
            if p is None:wr[i]=local[i];wp[i]=pos[i]
            else:wr[i]=wr[p]@local[i];wp[i]=wp[p]+wr[p]@pos[i]
        a=wp[self.ia];b=wp[self.ib];delta=b-a
        x=a+delta*self.sf+np.einsum('nij,nj->ni',wr[self.ia],self.so)
        y=a+delta*self.ef+np.einsum('nij,nj->ni',wr[self.ib],self.eo)
        return segment_distance(x[self.pi],y[self.pi],x[self.pj],y[self.pj])-self.radii[self.pi]-self.radii[self.pj]-self.margin
    def values(self,recipe,time):
        angles=np.zeros((len(self.nodes),3));pos=self.restpos.copy()
        for track in recipe['members']:
            n=self.names[track['bone']];duration=track.get('duration_ms',recipe['duration_ms']);t=np.clip((time-track.get('start_ms',0))/duration,0,1)
            if recipe.get('interpolation','smooth')=='smooth':t=t*t*(3-2*t)
            if 'keyframes' in track:
                keys=track['keyframes'];local=np.clip(time-track.get('start_ms',0),0,duration)
                j=min(np.searchsorted([k['time_ms'] for k in keys],local,side='right')-1,len(keys)-2);j=max(j,0)
                t=(local-keys[j]['time_ms'])/(keys[j+1]['time_ms']-keys[j]['time_ms'])
                if recipe.get('interpolation','smooth')=='smooth':t=t*t*(3-2*t)
                x,y=keys[j],keys[j+1]
            else:
                x={k.removeprefix('initial_'):v for k,v in track.items() if k.startswith('initial_')};y={k.removeprefix('final_'):v for k,v in track.items() if k.startswith('final_')}
            if 'rotation_deg' in x:
                aa=[0,0,0] if isinstance(x['rotation_deg'],str) else x['rotation_deg'];bb=y['rotation_deg']
                qa,qb=Rotation.from_euler('xyz',[aa,bb],degrees=True).as_quat();dot=np.dot(qa,qb)
                if dot<0:qb=-qb;dot=-dot
                if dot>.9995:q=qa+(qb-qa)*t
                else:
                    theta=math.acos(np.clip(dot,-1,1));q=(qa*math.sin((1-t)*theta)+qb*math.sin(t*theta))/math.sin(theta)
                angles[n]=Rotation.from_quat(q).as_euler('xyz',degrees=True)
            if 'position_height' in x:
                a=np.array([0,0,0] if isinstance(x['position_height'],str) else x['position_height']);pos[n]+=a+(np.array(y['position_height'])-a)*t
        return angles,pos
    def repair(self,recipe):
        duration=recipe['duration_ms'];times=sorted(set(range(0,duration+1,getattr(self,'step',50)))|{duration})
        values=[];previous=np.zeros(18);count=0;worst=1
        for time in times:
            angles,pos=self.values(recipe,time);base=angles[self.vars].reshape(-1).copy()
            gaps=self.gaps(angles,pos);delta=np.zeros(18)
            if min(gaps)<0.0029 or np.linalg.norm(previous)>0.02:
                def constraint(x):
                    a=angles.copy();a[self.vars]=(base+x).reshape(-1,3);return self.gaps(a,pos)-0.003
                def objective(x):return np.dot(x,x)+4.0*np.dot(x-previous,x-previous)
                res=minimize(objective,previous,method='SLSQP',bounds=[(-55,55)]*18,constraints=[{'type':'ineq','fun':constraint}],options={'maxiter':100,'ftol':1e-7})
                delta=res.x
                if min(constraint(delta))< -1e-5:raise RuntimeError(f'Cannot repair at {time}: {res.message} {min(constraint(delta))}')
                count+=1
            previous=delta;values.append((base+delta).reshape(-1,3));a=angles.copy();a[self.vars]=values[-1];worst=min(worst,min(self.gaps(a,pos)))
        if not count:return 0
        for k,index in enumerate(self.vars):
            name=self.nodes[index]['name'];track=next((t for t in recipe['members'] if t['bone']==name),None)
            if track is None:track={'bone':name};recipe['members'].append(track)
            # Arm bones in the bundled catalog carry rotations only.
            track.clear();track.update(bone=name,start_ms=0,duration_ms=duration,keyframes=[{'time_ms':t,'rotation_deg':np.round(v[k],6).tolist()} for t,v in zip(times,values)])
        # Linear interpolation keeps the calibrated path between close waypoints.
        recipe['interpolation']='linear'
        return count

def main():
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--profile',default='professor');p.add_argument('--ids',nargs='*');p.add_argument('--step',type=int,default=50);a=p.parse_args()
    path=ROOT/'AVATARES/movimentos.json';catalog=json.loads(path.read_text(encoding='utf-8'))
    profiles=sorted(p.name for p in (ROOT/'AVATARES').iterdir() if (p/'modelo.gltf').exists()) if a.profile=='all' else [a.profile]
    for profile in profiles:
        rig=Rig(profile);rig.step=a.step
        for m in catalog['movements']:
            if a.ids and m['id'] not in a.ids:continue
            if profile=='professor':recipe=m
            else:
                m.setdefault('profiles',{});recipe=m['profiles'].setdefault(profile,copy.deepcopy({k:v for k,v in m.items() if k in ['duration_ms','transition_ms','return_ms','finish','interpolation','members']}))
            n=rig.repair(recipe)
            if n:print(profile,m['id'],n,flush=True)
        from export_movement_timelines import layout
        path.write_text(layout(catalog)+'\n',encoding='utf-8')
        print('PROFILE COMPLETE',profile,flush=True)
if __name__=='__main__':main()
