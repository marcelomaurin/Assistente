"""Reference-based Zé Gotinha mascot, using the application's existing rig.

Run through game_avatar.py --profile ze_gotinha. Geometry is authored here;
the reference images are visual references, not redistributed source assets.
"""
import base64
import json
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import game_avatar as game


class ZeGotinha(game.Avatar):
    def __init__(self):
        super().__init__('ze_gotinha')
        # Start from the undeformed anatomy. Short legs, a rounded torso and
        # broad soft hands/feet replace the adult-in-white-clothes silhouette.
        p = self.p0 + game.target('caucasian-male-young', len(self.p0))
        floor = p[self.faces[self.groups == 'body', :, 0].reshape(-1), 1].min()
        q = (p - [0, floor, 0]) * .1
        y = q[:, 1].copy()
        q[:, 1] = np.interp(y, [0,.1,.5,.93,1.15,1.4,1.5,1.8],
                                  [0,.09,.28,.49,.67,.87,.95,1.45])
        q[:, 0] *= np.interp(y, [0,.5,.93,1.2,1.5], [1.3,1.35,1.35,1.15,1.05])
        q[y<.93,0] *= np.interp(y[y<.93],[0,.5,.93],[.60,.70,.82])
        q[:, 2] *= 1.35
        # Smooth the anatomical torso into a seamless, sexless mascot suit.
        torso = (y > .86) & (y < 1.43) & (np.abs(p[:,0]) < 1.55)
        h = q[torso, 1]
        theta = np.arctan2(q[torso,2]-.012, q[torso,0])
        rx = np.interp(h, [.45,.55,.68,.8,.9], [.17,.22,.235,.20,.14])
        rz = np.interp(h, [.45,.55,.68,.8,.9], [.14,.18,.19,.15,.11])
        blend = np.minimum(np.clip((y[torso]-.86)/.10,0,1),
                           np.clip((1.43-y[torso])/.12,0,1))
        q[torso,0] = q[torso,0]*(1-blend) + rx*np.cos(theta)*blend
        q[torso,2] = q[torso,2]*(1-blend) + (.012+rz*np.sin(theta))*blend
        self.original_y = y
        self.p = q * 10
        self.shift = np.zeros(3)
        self.floor = 0
        self.origins = {name:self.world(self.p[self.rig['joints'][b['head']]].mean(0))
                        for name,b in self.rig['bones'].items()}
        self.origins['head'] = np.array([0,.98,0])
        self.origins['jaw'] = np.array([0,1.15,.14])
        self.origins['eye.L'] = np.array([.085,1.245,.184])
        self.origins['eye.R'] = np.array([-.085,1.245,.184])
        for side in ('L','R'):
            self.origins['wrist.'+side][2]=.04
            wrist=self.origins['wrist.'+side]
            direction=wrist-self.origins['lowerarm01.'+side]
            direction/=np.linalg.norm(direction)
            lateral=np.array([-direction[1],direction[0],0])
            for finger in range(1,6):
                offset=(finger-3.5)*.020 if finger>1 else .047
                length={1:.045,2:.055,3:.070,4:.064,5:.048}[finger]
                start=wrist+direction*(.053 if finger>1 else .015)+lateral*offset
                forward=direction if finger>1 else (direction+lateral)*.707
                for seg in range(1,4):
                    bone=f'finger{finger}-{seg}.{side}'
                    self.origins[bone]=start+forward*length*(seg-1)/3
                    tail=self.rig['joints'][self.rig['bones'][bone]['tail']]
                    self.p[tail]=(start+forward*length*seg/3)*10
            shoulder=self.origins['upperarm01.'+side].copy()
            moving=[n for n in self.bones if n.endswith('.'+side) and n.startswith(('upperarm','lowerarm','wrist','finger'))]
            for name in moving:self.origins[name]=shoulder+(self.origins[name]-shoulder)*.83
            tails={i for n in moving for i in self.rig['joints'][self.rig['bones'][n]['tail']]}
            for i in tails:self.p[i]=(shoulder+(self.p[i]*.1-shoulder)*.83)*10
        inverse = []
        for name,b in self.rig['bones'].items():
            parent=b['parent']
            self.doc['nodes'][self.bone_nodes[name]]['translation'] = (
                self.origins[name]-(self.origins[parent] if parent else 0)).tolist()
            m=np.eye(4);m[:3,3]=-self.origins[name];inverse.append(m.T.reshape(-1))
        self.doc['skins'][0]['inverseBindMatrices']=self.acc(inverse,'MAT4')

    def facial_drivers(self):
        # Custom facial meshes use skeletal scale/translation tracks below.
        self.face_bones=[]
        return np.zeros((3,0,3))

    def surface(self,name,points,triangles,material,bone='head',uv=None):
        points=np.asarray(points)
        faces=np.array([[[v,v] for v in tri] for tri in triangles])
        return self.mesh(name,points-self.origins[bone],
                         np.zeros((len(points),2)) if uv is None else np.array(uv),
                         faces,material,parent=bone)

    def curve(self,name,points,radius,material,bone='head'):
        # Shared ring vertices yield smooth normals along curved eyebrows/lips.
        points=np.asarray(points);vertices=[];faces=[];cols=10
        for j,p in enumerate(points):
            tangent=points[min(j+1,len(points)-1)]-points[max(j-1,0)]
            tangent/=np.linalg.norm(tangent)
            side=np.cross(tangent,[0,0,1]);side/=np.linalg.norm(side)
            normal=np.cross(tangent,side)
            for i in range(cols):
                a=i/cols*math.tau
                vertices.append(p+radius*(side*math.cos(a)+normal*math.sin(a)))
            if j:
                for i in range(cols):
                    a=(j-1)*cols+i;b=(j-1)*cols+(i+1)%cols
                    faces.extend([(a,b,b+cols),(a,b+cols,a+cols)])
        return self.surface(name,vertices,faces,material,bone)

    def build(self):
        white=self.material('Marfim suave do mascote',(.94,.93,.88),rough=.65)
        ink=self.material('Sobrancelhas e sorriso',(.075,.09,.095),rough=.75)
        eye_white=self.material('Branco dos olhos',(.99,.99,.97),rough=.32)
        iris=self.material('Íris azul petróleo',(.035,.24,.32),rough=.3)
        pupil=self.material('Pupila',(.009,.019,.023),rough=.3)
        oral=self.material('Interior da boca',(.12,.035,.026),rough=.8)
        self.face_node=self.rounded_body(white)
        # Dense lathed rings, with a curved offset at the apex, form a true drop.
        from scipy.interpolate import PchipInterpolator
        heights=np.array([.935,.96,1.01,1.08,1.16,1.23,1.30,1.37,1.44,1.50,1.54])
        radii=np.array([0,.09,.17,.219,.235,.224,.190,.140,.078,.022,0])
        radius=PchipInterpolator(heights,radii)
        self.drop_radius=radius
        points=[];uv=[];faces=[];rows=64;cols=96
        for j,y in enumerate(np.linspace(heights[0],heights[-1],rows+1)):
            r=float(radius(y));offset=.095*np.clip((y-1.30)/.24,0,1)**1.6
            for i in range(cols+1):
                a=i/cols*math.tau
                points.append([offset+r*math.cos(a),y,r*.90*math.sin(a)])
                uv.append([i/cols,j/rows])
                if j and i:
                    k=j*(cols+1)+i
                    faces.extend([(k-cols-2,k,k-1),(k-cols-2,k-cols-1,k)])
        self.surface('Cabeça em gota com ponta curva',points,faces,white,uv=uv)
        self.eye_nodes=[]
        for side,sign in [('L',1),('R',-1)]:
            center=self.origins['eye.'+side]
            first=len(self.doc['nodes'])
            self.accessory('Olho '+side,center,[.033,.045,.017],eye_white,'eye.'+side)
            self.accessory('Íris '+side,center+[0,-.002,.016],[.019,.029,.007],iris,'eye.'+side)
            self.accessory('Pupila '+side,center+[0,-.002,.022],[.010,.021,.004],pupil,'eye.'+side)
            self.accessory('Brilho '+side,center+[-.006,.010,.026],[.006,.008,.002],eye_white,'eye.'+side)
            self.eye_nodes.extend(range(first,len(self.doc['nodes'])))
            brow=[]
            for t in np.linspace(-1,1,24):
                x=sign*.085+t*.037;y=1.318+.014*(1-t*t)
                z=math.sqrt(max(0,float(radius(y))**2-x*x))*.9+.008
                brow.append([x,y,z])
            self.curve('Sobrancelha '+side,brow,.004,ink)
        # A curved smile follows the front of the head, without human lips/nose.
        lip=[];vertices=[];tri=[]
        for i,t in enumerate(np.linspace(-1,1,49)):
            x=t*.105;upper=1.122+.027*t*t
            z=math.sqrt(max(0,float(radius(upper))**2-x*x))*.9+.009
            lip.append([x,upper,z])
            vertices.extend([[x,upper,z],[x,upper-.012*(1-t*t),z+.001]])
            if i:tri.extend([(2*i-2,2*i-1,2*i),(2*i-1,2*i+1,2*i)])
        mouth_weights=np.zeros((len(vertices),len(self.bones)))
        mouth_weights[0::2,self.bone_index['head']]=1
        mouth_weights[1::2,self.bone_index['jaw']]=1
        triangles=np.array(tri)
        self.mouth_node=self.mesh('Boca articulada',np.array(vertices),np.zeros((len(vertices),2)),
                                  np.stack([triangles,triangles],axis=-1),oral,mouth_weights)
        self.curve('Sorriso suave',lip,.0035,ink,'head')
        self.make_emblem()
        self.animate()
        self.animate_face()
        self.doc['asset']['generator']='Assistente Zé Gotinha reference mascot v5'
        self.doc['buffers']=[{'byteLength':len(self.binary),'uri':'data:application/octet-stream;base64,'+base64.b64encode(self.binary).decode()}]
        self.doc['extras']={'profile':'ze_gotinha','authoring':'Original reference-based mascot geometry; adapted MakeHuman CC0 body rig',
            'body':'continuous rounded mascot body; no clothing or shoes layers',
            'facial_animation':'skeletal jaw, gaze, animated eye scaling for blink',**self.stats}
        (self.folder/'modelo.gltf').write_text(json.dumps(self.doc,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
        (self.folder/'modelo.ini').write_text('[animations]\n'+'\n'.join(n+'='+n for n in game.CLIPS)+'\n',encoding='utf-8')
        (self.folder/'avatar.json').write_text(json.dumps({'id':'ze_gotinha','name':'Zé Gotinha','model':'modelo.gltf',
             'version':5,'license':'See NOTICE.md: original adaptation; third-party character and SUS mark'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print('ze_gotinha',self.stats,'buffer',len(self.binary),flush=True)

    def rounded_body(self,material):
        # Smooth implicit union, polygonized with shared tetrahedron edges.
        # This produces one closed surface rather than intersecting toy limbs.
        pieces=[]
        def ell(c,r,b):pieces.append(('ell',np.array(c),np.array(r),b))
        def capsule(a,b,r,bone):pieces.append(('cap',np.array(a),np.array(b),r,bone))
        ell([0,.675,.012],[.225,.255,.17],'spine01')
        ell([0,.49,0],[.17,.12,.13],'spine05')
        ell([0,.89,0],[.102,.10,.095],'neck01')
        for side,sign in [('L',1),('R',-1)]:
            shoulder=self.origins['upperarm01.'+side]
            elbow=self.origins['lowerarm01.'+side]
            wrist=self.origins['wrist.'+side]
            capsule([sign*.12,.835,0],shoulder,.065,'clavicle.'+side)
            capsule(shoulder,elbow,.060,'upperarm01.'+side)
            capsule(elbow,wrist,.050,'lowerarm01.'+side)
            palm=(wrist+self.origins['finger3-1.'+side])/2
            ell(palm,[.052,.052,.043],'wrist.'+side)
            for finger in range(1,6):
                for seg in range(1,4):
                    bone=f'finger{finger}-{seg}.{side}'
                    start=self.origins[bone]
                    end=self.world(self.p[self.rig['joints'][self.rig['bones'][bone]['tail']]].mean(0))
                    capsule(start,end,.018 if finger==1 else .016,bone)
            hip=self.origins['upperleg01.'+side]
            knee=self.origins['lowerleg01.'+side]
            ankle=self.origins['foot.'+side]
            capsule(hip,knee,.083,'upperleg01.'+side)
            capsule(knee,ankle,.073,'lowerleg01.'+side)
            ell(ankle+[0,-.012,.035],[.090,.070,.135],'foot.'+side)
        def distances(points,piece):
            if piece[0]=='ell':
                _,center,radii,_=piece
                return (np.linalg.norm((points-center)/radii,axis=1)-1)*min(radii)
            _,a,b,r,_=piece;d=b-a
            t=np.clip((points-a)@d/max(np.dot(d,d),1e-12),0,1)
            return np.linalg.norm(points-a-t[:,None]*d,axis=1)-r
        def field(points):
            result=np.full(len(points),10.)
            for piece in pieces:
                d=distances(points,piece);k=.023 if piece[-1].startswith(('spine','neck','upper','lower')) else .009
                h=np.maximum(k-np.abs(result-d),0)/k
                result=np.minimum(result,d)-h*h*k*.25
            return result
        step=.012
        axes=[np.arange(-.73,.73+step,step),np.arange(-.025,1.025+step,step),np.arange(-.23,.40+step,step)]
        grid=np.stack(np.meshgrid(*axes,indexing='ij'),axis=-1)
        shape=grid.shape[:3];points=grid.reshape(-1,3);values=field(points)
        ids=np.arange(len(points)).reshape(shape)
        corners=np.array([ids[:-1,:-1,:-1],ids[1:,:-1,:-1],ids[1:,1:,:-1],ids[:-1,1:,:-1],
                          ids[:-1,:-1,1:],ids[1:,:-1,1:],ids[1:,1:,1:],ids[:-1,1:,1:]]).reshape(8,-1).T
        active=(values[corners].min(1)<0)&(values[corners].max(1)>0)
        corners=corners[active];edges=[]
        for tet in [(0,1,2,6),(0,2,3,6),(0,3,7,6),(0,7,4,6),(0,4,5,6),(0,5,1,6)]:
            t=corners[:,tet];inside=values[t]<0
            for mask in range(1,15):
                selected=t[(inside*(1<<np.arange(4))).sum(1)==mask]
                if not len(selected):continue
                neg=[i for i in range(4) if mask&(1<<i)];pos=[i for i in range(4) if not mask&(1<<i)]
                if len(neg)==1 or len(pos)==1:
                    single,many=(neg,pos) if len(neg)==1 else (pos,neg)
                    edges.append(np.stack([selected[:,[single[0],i]] for i in many],axis=1))
                else:
                    a,b=neg;c,d=pos
                    for es in [[(a,c),(a,d),(b,d)],[(a,c),(b,d),(b,c)]]:
                        edges.append(np.stack([selected[:,e] for e in es],axis=1))
        edges=np.concatenate(edges)
        unique,indices=np.unique(np.sort(edges.reshape(-1,2),axis=1),axis=0,return_inverse=True)
        a,b=unique.T;u=values[a]/(values[a]-values[b])
        vertices=points[a]+u[:,None]*(points[b]-points[a]);triangles=indices.reshape(-1,3)
        centers=vertices[triangles].mean(1)
        gradient=np.column_stack([(field(centers+np.eye(3)[i]*.001)-field(centers-np.eye(3)[i]*.001)) for i in range(3)])
        normal=np.cross(vertices[triangles[:,1]]-vertices[triangles[:,0]],vertices[triangles[:,2]]-vertices[triangles[:,0]])
        reverse=np.sum(normal*gradient,axis=1)<0
        triangles[reverse]=triangles[reverse][:,[0,2,1]]
        weights=np.zeros((len(vertices),len(self.bones)))
        ds=np.array([distances(vertices,p) for p in pieces]).T
        influence=np.exp(-np.clip((ds-ds.min(1,keepdims=True))/.025,0,50))
        for i,p in enumerate(pieces):weights[:,self.bone_index[p[-1]]]+=influence[:,i]
        weights/=weights.sum(1,keepdims=True)
        faces=np.stack([triangles,triangles],axis=-1)
        return self.mesh('Corpo arredondado contínuo',vertices,np.zeros((len(vertices),2)),faces,material,weights)

    def make_emblem(self):
        # A curved transparent decal keeps the SUS mark flush with the belly.
        image=Image.new('RGBA',(512,640),(0,0,0,0));draw=ImageDraw.Draw(image)
        blue=(0,89,151,255)
        for box in [(216,50,296,150),(116,150,216,230),(216,150,296,230),
                    (296,150,396,230),(216,230,296,330)]:draw.rectangle(box,fill=blue)
        draw.line([(220,155),(292,225)],fill=(120,177,205,255),width=5)
        font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',110)
        draw.text((256,405),'SUS',font=font,anchor='mm',fill=blue)
        path=self.folder/'emblema_sus.png';image.save(path)
        mat=self.material('Símbolo azul SUS',rough=.8,texture=path,alpha=True)
        vertices=[];uv=[];faces=[];cols=16;rows=20
        for j in range(rows+1):
            v=j/rows;y=.565+v*.255
            rz=np.interp(y,[.55,.68,.8,.9],[.18,.19,.15,.11])
            rx=np.interp(y,[.55,.68,.8,.9],[.22,.235,.20,.14])
            for i in range(cols+1):
                u=i/cols;x=(u-.5)*.17
                z=.012+rz*math.sqrt(max(0,1-(x/rx)**2))+.003
                vertices.append([x,y,z]);uv.append([u,1-v])
                if i and j:
                    k=j*(cols+1)+i;faces.extend([(k-cols-2,k,k-1),(k-cols-2,k-cols-1,k)])
        self.surface('Emblema SUS no peito',vertices,faces,mat,'spine01',uv)

    def animate_face(self):
        for animation in self.doc['animations']:
            animation['channels']=[c for c in animation['channels'] if c['target']['path']!='weights']
            # The mascot's arms rest beside its belly. Keep the established
            # gesture poses for waving, thinking, applause and overhead reach.
            if not any(s in animation['name'] for s in ('wave','thinking','applause','right_hand_up')):
                for c in animation['channels']:
                    node=c['target']['node']
                    for side,angle in [('L',-30),('R',30)]:
                        if node==self.bone_nodes['upperarm01.'+side] and c['target']['path']=='rotation':
                            sampler=animation['samplers'][c['sampler']]
                            a=self.doc['accessors'][sampler['output']];v=self.doc['bufferViews'][a['bufferView']]
                            values=np.frombuffer(self.binary,dtype='<f4',count=a['count']*4,offset=v['byteOffset']).reshape(-1,4).copy()
                            values=np.array([game.qmul(q,game.quat(z=angle)) for q in values])
                            sampler['output']=self.acc(values,'VEC4')
            name=animation['name'];duration=1.2 if name.startswith('walk') else 2.4 if name.startswith(('wave','applause')) else 6.
            # Use the exported root channel duration as the single source of truth.
            sampler=animation['samplers'][0]
            duration=self.doc['accessors'][sampler['input']]['max'][0]
            times=np.linspace(0,duration,max(3,int(duration*60)+1))
            blink=np.exp(-((times/duration-.72)/(.065/duration))**2)
            scales=np.column_stack([np.ones(len(times)),1-.94*blink,np.ones(len(times))])
            inp=self.acc(times,'SCALAR');out=self.acc(scales,'VEC3')
            for node in self.eye_nodes:
                index=len(animation['samplers'])
                animation['samplers'].append({'input':inp,'output':out,'interpolation':'LINEAR'})
                animation['channels'].append({'sampler':index,'target':{'node':node,'path':'scale'}})
            used=sorted({c['sampler'] for c in animation['channels']})
            remap={old:new for new,old in enumerate(used)}
            animation['samplers']=[animation['samplers'][i] for i in used]
            for c in animation['channels']:c['sampler']=remap[c['sampler']]


if __name__=='__main__':
    ZeGotinha().build()
