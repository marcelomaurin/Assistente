"""Build game-style, skinned glTF avatars from the vendored CC0 art data.

No MakeHuman program code is imported. See avatar-source/README.md for provenance.
Requires numpy and Pillow, only for offline asset authoring, not for the app.
"""
import base64
import json
import math
import shutil
from collections import defaultdict
from pathlib import Path
import numpy as np
from PIL import Image, ImageOps

SOURCE = Path(__file__).resolve().parent / 'avatar-source'
ROOT = SOURCE.parents[1] / 'AVATARES'
CLIPS = ['idle', 'listening', 'thinking', 'talking', 'wave', 'walk']
PROFILES = {
    'professor': ('Professor', 'caucasian-male-young', 'male_casualsuit03', 'short02', 'young_caucasian_male'),
    'medico': ('Médico', 'caucasian-male-young', 'male_casualsuit03', 'short02', 'young_caucasian_male'),
    'engenheiro': ('Engenheiro', 'african-male-young', 'male_worksuit01', 'short02', 'young_african_male'),
    'programador': ('Programador', 'african-male-young', 'male_casualsuit01', 'afro01', 'young_african_male'),
    'dona_de_casa': ('Dona de casa', 'african-female-young', 'female_casualsuit01', 'bob01', 'young_african_female'),
    'empresario': ('Empresário', 'caucasian-male-young', 'male_elegantsuit01', 'short02', 'young_caucasian_male'),
    'padre': ('Padre', 'caucasian-male-old', 'male_elegantsuit01', 'short02', 'old_caucasian_male'),
    'crianca': ('Criança', 'caucasian-male-child', 'male_casualsuit02', 'short03', 'young_caucasian_male'),
    'bebe': ('Bebê', 'caucasian-male-baby', 'male_casualsuit02', 'short03', 'young_caucasian_male'),
    'robo': ('Robô', 'caucasian-female-young', 'male_casualsuit01', None, None),
}

def obj(path):
    positions, texcoords, faces, groups = [], [], [], []
    group = 'body'
    for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
        values = line.split()
        if not values: continue
        if values[0] == 'v': positions.append([float(v) for v in values[1:4]])
        elif values[0] == 'vt': texcoords.append([float(values[1]), 1-float(values[2])])
        elif values[0] == 'g': group = values[1]
        elif values[0] == 'f':
            face = [tuple(int(x)-1 for x in v.split('/')[:2]) for v in values[1:]]
            for i in range(1, len(face)-1):
                faces.append([face[0], face[i], face[i+1]]); groups.append(group)
    return np.array(positions), np.array(texcoords), np.array(faces), np.array(groups)

def target(name, count):
    result = np.zeros((count, 3))
    for line in (SOURCE / (name + '.target')).read_text().splitlines():
        v = line.split()
        if v and not v[0].startswith('#'): result[int(v[0])] = [float(f) for f in v[1:4]]
    return result

def normals(p, triangles):
    n = np.zeros_like(p)
    t = p[triangles]
    cross = np.cross(t[:, 1]-t[:, 0], t[:, 2]-t[:, 0])
    for i in range(3): np.add.at(n, triangles[:, i], cross)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)

def quat(x=0., y=0., z=0.):
    x,y,z=math.radians(x)/2,math.radians(y)/2,math.radians(z)/2
    cx,cy,cz,sx,sy,sz=math.cos(x),math.cos(y),math.cos(z),math.sin(x),math.sin(y),math.sin(z)
    return [sx*cy*cz-cx*sy*sz, cx*sy*cz+sx*cy*sz, cx*cy*sz-sx*sy*cz, cx*cy*cz+sx*sy*sz]

def ease(t):
    t=max(0.,min(1.,t))
    return t*t*t*(t*(t*6-15)+10)

def qmul(a,b):
    av,bv=np.array(a[:3]),np.array(b[:3])
    return np.r_[a[3]*bv+b[3]*av+np.cross(av,bv),a[3]*b[3]-np.dot(av,bv)]

def qinverse(q): return np.array([-q[0],-q[1],-q[2],q[3]])

def qrotate(q,v): return qmul(qmul(q,np.r_[v,0]),qinverse(q))[:3]

def between(a,b):
    a=np.array(a)/np.linalg.norm(a);b=np.array(b)/np.linalg.norm(b)
    q=np.r_[np.cross(a,b),1+np.dot(a,b)]
    if np.linalg.norm(q)<1e-8: return np.array([1.,0,0,0])
    return q/np.linalg.norm(q)

def qblend(a,b,t):
    a,b=np.array(a),np.array(b)
    if np.dot(a,b)<0:b=-b
    q=(1-t)*a+t*b
    return q/np.linalg.norm(q)

class Avatar:
    def __init__(self, profile):
        self.profile = profile
        self.label, shape, self.outfit, self.hair, self.skin = PROFILES[profile]
        self.folder = ROOT / profile
        self.folder.mkdir(parents=True, exist_ok=True)
        self.p0, self.uv, self.faces, self.groups = obj(SOURCE / 'base.obj')
        self.p = self.p0 + target(shape, len(self.p0))
        self.p += target('mouth-corner-puller', len(self.p0))*(.18 if profile!='robo' else .06)
        # Slightly enlarge head for a friendly game avatar while retaining facial anatomy.
        skull = self.p[:, 1] > (self.p[:, 1].max() - (2.25 if profile not in ('crianca','bebe') else 2.9))
        # Age target files already encode individual proportions, not a scaled adult.
        if profile not in ('crianca','bebe'):
            center = self.p[skull].mean(0)
            self.p[skull] = center + (self.p[skull]-center)*[1.045, 1.015, 1.035]
        self.floor = self.p[self.faces[self.groups == 'body', :, 0].reshape(-1), 1].min()
        self.shift = np.array([0., self.floor, 0.])
        self.rig = json.loads((SOURCE / 'default.mhskel').read_text())
        self.bones = list(self.rig['bones'])
        self.bone_index = {name: i for i, name in enumerate(self.bones)}
        self.origins = {name: self.world(self.p[self.rig['joints'][bone['head']]].mean(0))
                        for name, bone in self.rig['bones'].items()}
        raw_weights = json.loads((SOURCE / 'default_weights.mhw').read_text())['weights']
        self.weights = np.zeros((len(self.p), len(self.bones)), dtype=np.float32)
        for name, values in raw_weights.items():
            v = np.array(values); self.weights[v[:, 0].astype(int), self.bone_index[name]] = v[:, 1]
        self.weights /= np.maximum(self.weights.sum(axis=1, keepdims=True), 1e-9)
        self.doc = {'asset': {'version': '2.0', 'generator': 'Assistente game avatar v4; MakeHuman CC0 art + original adaptation'},
                    'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'name': self.label, 'children': []}],
                    'meshes': [], 'materials': [], 'bufferViews': [], 'accessors': [], 'animations': [],
                    'images': [], 'textures': [], 'samplers': [{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}]}
        self.binary = bytearray()
        self.bone_nodes = {}
        for name in self.bones:
            self.bone_nodes[name] = len(self.doc['nodes'])
            self.doc['nodes'].append({'name': name, 'children': []})
        for name, bone in self.rig['bones'].items():
            parent = bone['parent']
            self.doc['nodes'][self.bone_nodes[name]]['translation'] = (self.origins[name]-(self.origins[parent] if parent else 0)).tolist()
            self.doc['nodes'][self.bone_nodes[parent] if parent else 0]['children'].append(self.bone_nodes[name])
        inverse = []
        for name in self.bones:
            matrix = np.eye(4); matrix[:3, 3] = -self.origins[name]
            inverse.append(matrix.T.reshape(-1))
        self.doc['skins'] = [{'name': 'Human continuous skin', 'joints': list(self.bone_nodes.values()),
                              'skeleton': self.bone_nodes['root'],
                              'inverseBindMatrices': self.acc(inverse, 'MAT4')}]
        self.face_node = None
        self.stats = {'triangles': 0, 'vertices': 0, 'joints': len(self.bones)}
        self._textures = {}

    def world(self, p): return (np.asarray(p)-self.shift)*.1

    def acc(self, values, typ, component=5126):
        dtype = {5126: '<f4', 5123: '<u2', 5125: '<u4'}[component]
        values = np.asarray(values, dtype=dtype)
        while len(self.binary) % 4: self.binary.append(0)
        start = len(self.binary); self.binary.extend(values.tobytes())
        view = len(self.doc['bufferViews'])
        self.doc['bufferViews'].append({'buffer': 0, 'byteOffset': start, 'byteLength': len(self.binary)-start})
        rows = values.reshape(len(values), -1)
        a = {'bufferView': view, 'componentType': component, 'count':len(values), 'type':typ}
        if component == 5126:
            a.update(min=rows.min(0).tolist(), max=rows.max(0).tolist())
        self.doc['accessors'].append(a)
        return len(self.doc['accessors'])-1

    def texture(self, path):
        path = Path(path)
        if path not in self._textures:
            name = path.name
            dest = self.folder / name
            if path.resolve() != dest.resolve(): shutil.copyfile(path, dest)
            image = len(self.doc['images']); self.doc['images'].append({'uri': name})
            self._textures[path] = len(self.doc['textures'])
            self.doc['textures'].append({'source': image, 'sampler': 0})
        return {'index': self._textures[path]}

    def material(self, name, color=(1,1,1), rough=.7, metal=0, texture=None, normal=None, ao=None, alpha=False):
        pbr = {'baseColorFactor':list(color)+[1], 'roughnessFactor':rough, 'metallicFactor':metal}
        m = {'name':name, 'pbrMetallicRoughness':pbr, 'doubleSided':True}
        if texture: pbr['baseColorTexture'] = self.texture(texture)
        if normal: m['normalTexture'] = dict(self.texture(normal), scale=.55)
        if ao: m['occlusionTexture'] = dict(self.texture(ao), strength=.7)
        if alpha: m.update(alphaMode='MASK', alphaCutoff=.35)
        self.doc['materials'].append(m)
        return len(self.doc['materials'])-1

    def mesh(self, name, p, uv, faces, material, weights=None, parent=None, morphs=None):
        if len(faces) == 0: return None
        # Split only at UV seams; share normals across seams before splitting.
        triangles = faces[:, :, 0]
        n = normals(p, triangles)
        pairs, remap = np.unique(faces.reshape(-1, 2), axis=0, return_inverse=True)
        pi, ti = pairs.T
        attrs = {'POSITION':self.acc(p[pi], 'VEC3'), 'NORMAL':self.acc(n[pi], 'VEC3'),
                 'TEXCOORD_0':self.acc(uv[ti], 'VEC2')}
        if weights is not None:
            w = weights[pi]
            joint = np.argsort(-w, axis=1, kind='stable')[:, :4]
            top = np.maximum(np.take_along_axis(w, joint, axis=1), 0)
            top /= np.maximum(top.sum(axis=1, keepdims=True), 1e-12)
            attrs.update(JOINTS_0=self.acc(joint,'VEC4',5123), WEIGHTS_0=self.acc(top,'VEC4'))
        primitive = {'attributes':attrs, 'indices':self.acc(remap, 'SCALAR',5125), 'material':material}
        mesh = {'name':name, 'primitives':[primitive]}
        if morphs:
            primitive['targets'] = [{'POSITION':self.acc(delta[pi], 'VEC3'),
                                     'NORMAL':self.acc((normals(p+delta,triangles)-n)[pi], 'VEC3')} for delta in morphs]
            mesh['weights'] = [0]*len(morphs)
            mesh['extras'] = {'targetNames':['jawOpen','blink','smile']}
        idx = len(self.doc['meshes']); self.doc['meshes'].append(mesh)
        node = {'name':name, 'mesh':idx}
        if weights is not None: node['skin'] = 0
        ni = len(self.doc['nodes']); self.doc['nodes'].append(node)
        self.doc['nodes'][0 if parent is None else self.bone_nodes[parent]]['children'].append(ni)
        self.stats['triangles'] += len(faces); self.stats['vertices'] += len(pi)
        return ni

    def fit(self, category, name):
        directory = SOURCE / 'system' / category / name
        p, uv, faces, _ = obj(directory / (name+'.obj'))
        scale = np.ones(3); refs=[]; mixes=[]; offsets=[]; active=False; hide=set()
        for line in (directory / (name+'.mhclo')).read_text(errors='replace').splitlines():
            v = line.split()
            if not v or v[0].startswith('#'): continue
            if v[0] in ('x_scale','y_scale','z_scale'):
                axis = 'xyz'.index(v[0][0]); scale[axis] = abs(self.p[int(v[1]),axis]-self.p[int(v[2]),axis])/float(v[3])
            elif v[0] == 'verts': active=True
            elif v[0] == 'delete_verts': active=False
            elif active and v[0].lstrip('-').isdigit():
                if len(v) == 1: refs.append([int(v[0])]*3); mixes.append([1,0,0]); offsets.append([0,0,0])
                else: refs.append(list(map(int,v[:3]))); mixes.append(list(map(float,v[3:6]))); offsets.append(list(map(float,v[6:9])))
        refs=np.array(refs); mixes=np.array(mixes)
        if len(refs) != len(p): raise ValueError(f'{name}: mapping {len(refs)} != {len(p)}')
        p=(self.p[refs]*mixes[:,:,None]).sum(axis=1)+np.array(offsets)*scale
        w=(self.weights[refs]*np.maximum(mixes[:,:,None],0)).sum(axis=1)
        w/=np.maximum(w.sum(axis=1,keepdims=True),1e-12)
        p=self.world(p)
        if category=='clothes':p,w=self.cloth_clearance(p,w)
        return p, uv, faces, w, directory

    def cloth_clearance(self, p, weights, clearance=.008):
        # Fit to the actual body surface, not just the MakeHuman helper cage.
        # A small outward allowance prevents skin from crossing tight garments.
        # The body remains intact and can be rendered without the clothing.
        if not hasattr(self, '_body_surface'):
            points=self.world(self.p)
            triangles=self.faces[self.groups=='body',:,0]
            normal=normals(points,triangles)
            grid=defaultdict(list);adjacent=defaultdict(set)
            for vertex in np.unique(triangles):
                grid[tuple(np.floor(points[vertex]/.05).astype(int))].append(vertex)
            for i,tri in enumerate(triangles):
                for vertex in tri:adjacent[vertex].add(i)
            self._body_surface=points,triangles,normal,grid,adjacent
        points,triangles,normal,grid,adjacent=self._body_surface
        p=p.copy();weights=weights.copy()
        field=np.zeros(len(points));queries=[]
        for i,point in enumerate(p):
            cell=np.floor(point/.05).astype(int)
            near=[]
            for x in range(-1,2):
                for y in range(-1,2):
                    for z in range(-1,2):near.extend(grid.get(tuple(cell+[x,y,z]),()))
            if not near:continue
            near=np.array(near)
            distances=((points[near]-point)**2).sum(1)
            nearest=near[np.argsort(distances)[:8]]
            candidates=set()
            for vertex in nearest:candidates.update(adjacent[vertex])
            ids=np.array(sorted(candidates));tri=triangles[ids]
            a,b,c=points[tri].transpose(1,0,2)
            ab=b-a;ac=c-a;ap=point-a
            aa=(ab*ab).sum(1);bb=(ab*ac).sum(1);cc=(ac*ac).sum(1)
            pa=(ap*ab).sum(1);pc=(ap*ac).sum(1)
            denom=np.maximum(aa*cc-bb*bb,1e-18)
            v=(cc*pa-bb*pc)/denom;w=(aa*pc-bb*pa)/denom
            projected=a+ab*v[:,None]+ac*w[:,None]
            valid=(v>=0)&(w>=0)&(v+w<=1)
            choices=[projected]
            for start,end in ((a,b),(b,c),(c,a)):
                edge=end-start
                u=np.clip(((point-start)*edge).sum(1)/np.maximum((edge*edge).sum(1),1e-18),0,1)
                choices.append(start+u[:,None]*edge)
            choices=np.array(choices)
            distance=((choices-point)**2).sum(2);distance[0,~valid]=np.inf
            choice,index=np.unravel_index(np.argmin(distance),distance.shape)
            closest=choices[choice,index]
            if distance[choice,index]>.07**2:continue
            delta=closest-a[index]
            da=np.dot(delta,ab[index]);dc=np.dot(delta,ac[index])
            v=(cc[index]*da-bb[index]*dc)/denom[index]
            w=(aa[index]*dc-bb[index]*da)/denom[index]
            bary=np.maximum([1-v-w,v,w],0);bary/=bary.sum()
            n=(normal[tri[index]]*bary[:,None]).sum(0)
            n/=max(np.linalg.norm(n),1e-12)
            signed=np.dot(point-closest,n)
            needed=max(0,clearance-signed)
            for vertex in tri[index]:field[vertex]=max(field[vertex],needed)
            queries.append((i,n,nearest))
            # Follow the same nearby skin as the fitted cloth to retain the
            # allowance when arms and shoulders move.
            weights[i]=(self.weights[tri[index]]*bary[:,None]).sum(0)
        # Move nearby layers by a common body-surface allowance. Clamping
        # each layer independently to the same distance collapses a shirt and
        # overalls into one surface and creates depth-fighting patches.
        for i,n,nearest in queries:p[i]+=field[nearest].max()*n
        weights/=np.maximum(weights.sum(1,keepdims=True),1e-12)
        return p,weights

    def accessory(self, name, center, radii, mat, bone='head', kind='sphere', rotation=0):
        p=[]; uv=[]; faces=[]
        rows, cols = (16,32) if kind=='sphere' else (12,48)
        for j in range(rows+1):
            t=j/rows
            for i in range(cols+1):
                a=i/cols*math.tau
                if kind=='torus':
                    b=t*math.tau; r=.83+.17*math.cos(b)
                    v=[r*math.cos(a), r*math.sin(a), .17*math.sin(b)]
                else:
                    b=-math.pi/2+t*math.pi
                    v=[math.cos(b)*math.cos(a), math.sin(b), math.cos(b)*math.sin(a)]
                v=np.array(v)*radii
                c,s=math.cos(rotation),math.sin(rotation)
                v=np.array([c*v[0]-s*v[1],s*v[0]+c*v[1],v[2]])
                p.append(v+center-self.origins[bone]); uv.append([i/cols,t])
        for j in range(rows):
            for i in range(cols):
                a=j*(cols+1)+i
                faces.extend([[[a,a],[a+cols+2,a+cols+2],[a+1,a+1]],
                              [[a,a],[a+cols+1,a+cols+1],[a+cols+2,a+cols+2]]])
        return self.mesh(name,np.array(p),np.array(uv),np.array(faces),mat,parent=bone)

    def segment(self, name, a, b, radius, mat, bone='spine01'):
        # A smooth tube, used for stethoscope/headset rather than polygonal blocks.
        a,b=np.array(a),np.array(b); direction=b-a; direction/=np.linalg.norm(direction)
        x=np.cross(direction,[0,0,1])
        if np.linalg.norm(x)<.01: x=np.cross(direction,[1,0,0])
        x/=np.linalg.norm(x); z=np.cross(direction,x)
        p=[];uv=[];faces=[]
        for j in range(2):
            for i in range(13):
                ang=i/12*math.tau;p.append((a if j==0 else b)+radius*(x*math.cos(ang)+z*math.sin(ang))-self.origins[bone]);uv.append([i/12,j])
        for i in range(12):
            for tri in ((i,i+13,i+14),(i,i+14,i+1)):faces.append([[v,v] for v in tri])
        self.mesh(name,np.array(p),np.array(uv),np.array(faces),mat,parent=bone)

    def build(self):
        skin_dir=SOURCE/'system'/'skins'/(self.skin or 'young_caucasian_female')
        skin_tex=next(skin_dir.glob('*.png'))
        skinmat=self.material('Pele com textura',rough=.58,texture=skin_tex) if self.skin else self.material('Cerâmica branca',(.77,.81,.84),.28,.35)
        # Keep the complete skinned body underneath independent clothing meshes.
        # Cropping to head/hands leaves floating hands with short sleeves and
        # removes anatomy when a garment is hidden or replaced.
        body=self.faces[self.groups=='body']
        expression_scale=.075 if self.profile in ('crianca','bebe') else .1
        mouth=target('mouth-open',len(self.p))*expression_scale
        blink=(target('eye-left-closure',len(self.p))+target('eye-right-closure',len(self.p)))*expression_scale
        smile=target('mouth-corner-puller',len(self.p))*expression_scale
        self.face_node=self.mesh('Corpo completo: pele e anatomia',self.world(self.p),self.uv,body,skinmat,self.weights,morphs=[mouth,blink,smile])
        p,uv,f,w,d=self.fit('clothes',self.outfit)
        diffuse=next(d.glob('*diffuse.png'))
        normal=next(d.glob('*normal.png'),None);ao=next(d.glob('*_ao.png'),None)
        mat=self.material('Roupa: tecido normal e oclusão',rough=.87,texture=diffuse,normal=normal,ao=ao)
        original_mat=mat
        # Physician white coat and priest black suit retain sculpted cloth folds.
        if self.profile in ('professor','medico','padre','robo'):
            im=Image.open(diffuse).convert('RGB')
            if self.profile in ('professor','medico'): im=ImageOps.colorize(ImageOps.grayscale(im),'#87959b','#f4f7f5')
            elif self.profile=='padre': im=ImageOps.colorize(ImageOps.grayscale(im),'#080b11','#33404c')
            else: im=ImageOps.colorize(ImageOps.grayscale(im),'#17202b','#cbd4d9')
            path=self.folder/'uniforme.png';im.save(path)
            mat=self.material('Uniforme adaptado',rough=.75 if self.profile!='robo' else .32,metal=.35 if self.profile=='robo' else 0,texture=path,normal=normal,ao=ao)
        if self.profile in ('professor','medico'):
            upper=p[f[:,:,0],1].mean(1)>self.origins['spine05'][1]+.025
            self.mesh('Vestuário deformável',p,uv,f[upper],mat,w)
            self.mesh('Calças',p,uv,f[~upper],original_mat,w)
        else:self.mesh('Vestuário deformável',p,uv,f,mat,w)
        if self.profile=='professor':
            # A separate cloth shell on the fitted garment; own UVs and smooth weights.
            center=p[f[:,:,0]].mean(1)
            waist=self.origins['spine05'][1]
            neck=self.origins['neck01'][1]
            vest=(center[:,1]>waist+.015)&(center[:,1]<neck-.045)&(np.abs(center[:,0])<.178)
            vest &= (center[:,1] < neck-.15+np.abs(center[:,0])*.65)
            shell=p+normals(p,f[:,:,0])*.003
            vestuv=np.column_stack((p[:,0]*4,p[:,1]*4))
            vf=f[vest].copy();vf[:,:,1]=vf[:,:,0]
            pattern=self.folder/'roupa.png'
            pixels=np.zeros((512,512,3),dtype=np.uint8)
            yy,xx=np.indices((512,512));diamond=np.abs((xx%128)-64)+np.abs((yy%128)-64)
            pixels[:]=[31,65,85];pixels[diamond<58]=[175,183,168];pixels[np.abs(diamond-64)<2]=[98,136,151]
            pixels=np.maximum(pixels.astype(int)-(((xx+yy)%4==0)*7)[:,:,None],0).astype(np.uint8)
            Image.fromarray(pixels).save(pattern)
            self.mesh('Colete de tricô com UVs próprios',shell,vestuv,vf,self.material('Tricô argyle',rough=.94,texture=pattern),w)
        p,uv,f,w,d=self.fit('clothes','shoes05' if self.profile in ('crianca','bebe','programador') else 'shoes01')
        self.mesh('Calçados',p,uv,f,self.material('Couro e sola',rough=.7,texture=next(d.glob('*diffuse.png')),normal=next(d.glob('*normal.png'),None)),w)
        if self.hair:
            p,uv,f,w,d=self.fit('hair',self.hair)
            self.mesh('Cabelo com mechas e transparência recortada',p,uv,f,
                      self.material('Cabelo',rough=.68,texture=next(d.glob('*diffuse.png')),alpha=True),w)
        p,uv,f,w,d=self.fit('eyes','high-poly')
        eyes=SOURCE/'system'/'eyes'/'materials'/'brown_eye.png'
        if self.profile=='robo':
            im=Image.open(eyes).convert('RGBA'); rgb=np.array(im);dark=rgb[:,:,:3].mean(2)<130
            rgb[dark,:3]=np.array([30,190,204]);path=self.folder/'olhos_cianos.png';Image.fromarray(rgb).save(path);eyes=path
        self.mesh('Olhos: esclera íris e pupilas',p,uv,f,self.material('Córnea e íris',rough=.16,texture=eyes,alpha=True),w)
        p,uv,f,w,d=self.fit('eyebrows','eyebrow001')
        self.mesh('Sobrancelhas',p,uv,f,self.material('Sobrancelhas',rough=.85,texture=next(d.glob('*.png')),alpha=True),w)
        p,uv,f,w,d=self.fit('teeth','teeth_base')
        self.mesh('Dentes',p,uv,f,self.material('Esmalte',rough=.32,texture=d/'teeth.png'),w)
        self.details()
        self.animate()
        self.doc['buffers']=[{'byteLength':len(self.binary),'uri':'data:application/octet-stream;base64,'+base64.b64encode(self.binary).decode()}]
        self.doc['extras']={'profile':self.profile,'authoring':'CC0 MakeHuman art adapted for Assistente',
                            'rig':'linear blend skinning, 4 normalized influences per vertex',
                            'facial_animation':'skeletal jaw, muscle chains, eyelids and gaze; reference morph weights stay zero',
                            'body':'complete; clothing is a separate mesh', 'body_triangles':len(body), **self.stats}
        (self.folder/'modelo.gltf').write_text(json.dumps(self.doc,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
        (self.folder/'modelo.ini').write_text('[animations]\n'+'\n'.join(n+'='+n for n in CLIPS)+'\n',encoding='utf-8')
        (self.folder/'avatar.json').write_text(json.dumps({'id':self.profile,'name':self.label,'model':'modelo.gltf','license':'CC0-1.0','version':4},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(self.profile,self.stats,'buffer',len(self.binary),flush=True)

    def details(self):
        dark=self.material('Acessórios grafite',(.025,.035,.048),.38,.18)
        silver=self.material('Metal acetinado',(.66,.73,.78),.3,.72)
        white=self.material('Branco acetinado',(.86,.9,.92),.38,.15)
        cyan=self.material('Detalhes cianos',(.025,.58,.65),.28,.4)
        gold=self.material('Dourado',(.72,.43,.08),.28,.72)
        head=self.origins['head'];eye=self.origins['eye.L'];eyeR=self.origins['eye.R']
        height=(self.world(self.p).max(0)-self.world(self.p).min(0))[1]
        sc=height/1.78
        if self.profile in ('professor','programador'):
            for center in (eye,eyeR):
                c=center+[0,0,.030*sc]
                self.accessory('Armação dos óculos',c,np.array([.025,.019,.016])*sc,dark,kind='torus')
                self.segment('Haste dos óculos',c+[np.sign(c[0])*.03*sc,0,0],c+[np.sign(c[0])*.05*sc,0,-.08*sc],.0024*sc,dark,'head')
            self.segment('Ponte dos óculos',eye+[-.022*sc,0,.03*sc],eyeR+[.022*sc,0,.03*sc],.0022*sc,dark,'head')
        if self.profile=='engenheiro':
            top=self.world(self.p).max(0)[1]
            self.accessory('Capacete de segurança',[0,top-.025*sc,head[2]],np.array([.115,.08,.13])*sc,gold)
            self.accessory('Aba do capacete',[0,top-.065*sc,head[2]+.015*sc],np.array([.13,.008,.15])*sc,gold)
        if self.profile=='medico':
            neck=self.origins['neck01'];chest=self.origins['spine01'];c=neck+[0,-.13*sc,.09*sc]
            self.accessory('Tubo do estetoscópio',c,np.array([.075,.105,.014])*sc,dark,'spine01','torus')
            self.accessory('Diafragma',c+[.065*sc,-.105*sc,.005],np.array([.023,.023,.008])*sc,silver,'spine01')
        if self.profile=='padre':
            neck=self.origins['neck01']; c=neck+[0,-.022*sc,.072*sc]
            self.accessory('Colarinho clerical',c,np.array([.029,.011,.007])*sc,white,'neck01')
            c+=np.array([0,-.16*sc,.03*sc])
            self.segment('Crucifixo',c+[0,-.035*sc,0],c+[0,.035*sc,0],.004*sc,gold)
            self.segment('Crucifixo transversal',c+[-.022*sc,.014*sc,0],c+[.022*sc,.014*sc,0],.004*sc,gold)
        if self.profile=='bebe':
            # Leave the lips free to articulate. The old head-bound pacifier
            # sat inside the oral cavity and became visible when the jaw opened.
            c=self.origins['spine01']+np.array([.025,-.065,.10])*sc
            self.accessory('Chupeta presa à roupa',c,np.array([.035,.018,.009])*sc,cyan,'spine01')
            self.accessory('Anel da chupeta',c+[0,-.015*sc,.01*sc],np.array([.013,.015,.016])*sc,gold,'spine01',kind='torus')
        if self.profile=='robo':
            for side in (-1,1):
                c=head+np.array([side*.093,.045,0])*sc
                self.accessory('Headset auricular',c,np.array([.021,.054,.038])*sc,dark)
                self.accessory('Headset aro ciano',c+[side*.016*sc,0,0],np.array([.007,.043,.029])*sc,cyan)
            top=self.world(self.p).max(0)[1]
            points=[np.array([.1*math.cos(a)*sc,head[1]+.06*sc+.115*math.sin(a)*sc,head[2]-.015*sc]) for a in np.linspace(0,math.pi,22)]
            for a,b in zip(points,points[1:]):self.segment('Arco do headset',a,b,.007*sc,dark,'head')
            a=head+np.array([-.10,.015,.015])*sc;b=head+np.array([-.045,-.05,.10])*sc
            self.segment('Haste do microfone',a,b,.004*sc,dark,'head')
            self.accessory('Cápsula do microfone',b,np.array([.014,.009,.010])*sc,dark)
            for side in ('L','R'):
                for bone in ('upperarm01.','lowerarm01.'):
                    start=self.origins[bone+side]
                    tail=self.world(self.p[self.rig['joints'][self.rig['bones'][bone+side]['tail']]].mean(0))
                    self.accessory('Placa de braço',(start+tail)/2+[0,0,.025*sc],np.array([.045,.09,.030])*sc,white,bone+side)
                    self.segment('Inserto ciano',start+[0,-.025*sc,.05*sc],tail+[0,.03*sc,.05*sc],.007*sc,cyan,bone+side)

    def arm_ik(self, side, target, pole=None, shoulder_elevation=0.):
        # Share overhead reach across clavicle, shoulder and upper arm. Rotating
        # only upperarm01 bends the skin below the deltoid and leaves the shoulder
        # fixed in its bind pose, producing a displaced/pinched shoulder.
        sign=1 if side=='L' else -1
        clavicle=quat(0,0,sign*8*shoulder_elevation)
        shoulder=quat(-2*shoulder_elevation,0,sign*25*shoulder_elevation)
        c=self.origins['clavicle.'+side];sh=self.origins['shoulder01.'+side]
        target=c+qrotate(qinverse(clavicle),np.array(target)-c)
        target=sh+qrotate(qinverse(shoulder),target-sh)
        h=self.origins['upperarm01.'+side];k=self.origins['lowerarm01.'+side];a=self.origins['wrist.'+side]
        l1=np.linalg.norm(k-h);l2=np.linalg.norm(a-k)
        d=np.array(target)-h;distance=np.linalg.norm(d);direction=d/distance
        distance=min(distance,(l1+l2)*.98)
        pole=np.array([1 if side=='L' else -1,-.6,-.1] if pole is None else pole,dtype=float)
        pole-=np.dot(pole,direction)*direction;pole/=np.linalg.norm(pole)
        x=(l1*l1+distance*distance-l2*l2)/(2*distance)
        elbow=h+direction*x+pole*math.sqrt(max(0,l1*l1-x*x))
        q1=between(k-h,elbow-h)
        q2=between(a-k,qrotate(qinverse(q1),np.array(target)-elbow))
        return {'clavicle.'+side:clavicle,'shoulder01.'+side:shoulder,
                'upperarm01.'+side:q1,'lowerarm01.'+side:q2}

    def leg_ik(self, side, u, bob):
        h=self.origins['upperleg01.'+side];k=self.origins['lowerleg01.'+side];a=self.origins['foot.'+side]
        upper=k-h;lower=a-k
        l1=np.linalg.norm(upper[1:]);l2=np.linalg.norm(lower[1:]);length=l1+l2
        stride=length*.24
        if u<.6:
            f=u/.6;z=stride*(.5-f);lift=0.
        else:
            f=(u-.6)/.4
            # Hermite path matches backward stance speed at toe-off and landing.
            # A zero-speed ease here would cause a visible foot velocity jump.
            slope=-stride*.4/.6
            z=(2*f**3-3*f*f+1)*(-stride*.5)+(f**3-2*f*f+f)*slope+(-2*f**3+3*f*f)*(stride*.5)+(f**3-f*f)*slope
            lift=length*.075*math.sin(math.pi*f)**2
        dy=a[1]-h[1]-bob+lift;dz=a[2]-h[2]+z
        distance=min(math.hypot(dy,dz),length*.998)
        theta=math.atan2(dz,-dy)
        angle=math.acos(np.clip((l1*l1+distance*distance-l2*l2)/(2*l1*distance),-1,1))
        bend=math.acos(np.clip((distance*distance-l1*l1-l2*l2)/(2*l1*l2),-1,1))
        thigh=math.atan2(upper[2],-upper[1])-(theta+angle)
        shin=math.atan2(lower[2],-lower[1])-(theta+angle-bend)-thigh
        toeoff=12*math.sin(math.pi*min(1,max(0,(u-.42)/.18)))**2 if u<.6 else 0
        return math.degrees(thigh),math.degrees(shin),-math.degrees(thigh+shin)+toeoff

    def clap_wrist(self, side, arm):
        wrist=self.origins['wrist.'+side]
        forward=self.origins['finger3-3.'+side]-wrist
        thumb=self.origins['finger1-1.'+side]-wrist
        # Anatomical handedness matters: the same cross product points to the
        # palm on one hand and to the back of the mirrored hand on the other.
        palm=np.cross(thumb,forward) if side=='R' else np.cross(forward,thumb)
        desired=np.array([0.,1.,.12]);desired/=np.linalg.norm(desired)
        q=between(forward,desired)
        current=qrotate(q,palm);current-=desired*np.dot(current,desired);current/=np.linalg.norm(current)
        facing=np.array([1. if side=='R' else -1.,0.,0.])
        angle=math.atan2(np.dot(desired,np.cross(current,facing)),np.dot(current,facing))
        roll=np.r_[desired*math.sin(angle/2),math.cos(angle/2)]
        total=qmul(arm['upperarm01.'+side],arm['lowerarm01.'+side])
        local=qmul(qinverse(total),qmul(roll,q))
        axis=wrist-self.origins['lowerarm01.'+side];axis/=np.linalg.norm(axis)
        twist=np.r_[axis*np.dot(local[:3],axis),local[3]];twist/=np.linalg.norm(twist)
        partial=qblend(quat(),twist,.65)
        return partial,qmul(qinverse(partial),local)

    def facial_drivers(self):
        # The pinned CGE loader does not implement glTF morph animation. Fit the
        # CC0 expression references to the existing facial muscle chains instead.
        # Use exactly the four influences exported by mesh(), including ancestry.
        self.face_bones=[n for n in self.bones if n.startswith(
            ('levator','oris','orbicularis','oculi','temporalis','risorius'))]
        j=np.argsort(-self.weights,axis=1,kind='stable')[:,:4]
        w=np.take_along_axis(self.weights,j,axis=1);w/=np.maximum(w.sum(1,keepdims=True),1e-12)
        skin=np.zeros_like(self.weights);np.put_along_axis(skin,j,w,axis=1)
        descendants={}
        for name in self.bones:
            descendants[name]=[]
            for child in self.bones:
                ancestor=child
                while ancestor and ancestor!=name:ancestor=self.rig['bones'][ancestor]['parent']
                if ancestor==name:descendants[name].append(self.bone_index[child])
        influence=np.array([skin[:,descendants[n]].sum(1) for n in self.face_bones]).T
        body=np.unique(self.faces[self.groups=='body',:,0])
        a=influence[body].astype(float)
        scale=.075 if self.profile in ('crianca','bebe') else .1
        mouth=target('mouth-open',len(self.p))*scale
        # Subtract the mandibular hinge's contribution. Corrective lip/cheek
        # translations supplement the jaw rather than opening the chin twice.
        from_hinge=self.world(self.p)-self.origins['jaw']
        angle=math.radians(22);c,s=math.cos(angle),math.sin(angle)
        rotation=np.array([[1,0,0],[0,c,-s],[0,s,c]])
        jaw_delta=(from_hinge@rotation.T-from_hinge)*skin[:,descendants['jaw']].sum(1,keepdims=True)
        # Eye aperture does not shrink with stature in the age targets. Keep
        # the full unit conversion for eyelids instead of the mouth age scale.
        refs=[mouth-jaw_delta,
              (target('eye-left-closure',len(self.p))+target('eye-right-closure',len(self.p)))*.1,
              target('mouth-corner-puller',len(self.p))*scale]
        # Ridge regularization keeps nearly equivalent parent/child muscle
        # chains bounded, including profiles with small facial proportions.
        drivers=np.array([np.linalg.solve(a.T@a+np.eye(len(self.face_bones))*.02,a.T@d[body]) for d in refs])
        drivers[1]*=2.1 if self.profile=='crianca' else 1.5  # Fit the age-specific lid aperture.
        return drivers

    def finger_pose(self, side, phase, base, raised):
        if not hasattr(self,'_finger_axes'):self._finger_axes={}
        if not hasattr(self,'_finger_cache'):self._finger_cache={}
        key=(side,phase,base,raised)
        if key in self._finger_cache:return self._finger_cache[key]
        wrist=self.origins['wrist.'+side]
        forward=self.origins['finger3-3.'+side]-wrist
        thumb=self.origins['finger1-1.'+side]-wrist
        palm=np.cross(thumb,forward) if side=='R' else np.cross(forward,thumb)
        palm/=np.linalg.norm(palm)
        result={}
        for finger in range(1,6):
            # Long fingers use MCP/PIP/DIP; the thumb uses CMC/MCP/IP.
            # Flexion is smaller at the distal control.
            # Axes come from each profile's phalanges and mirrored palm basis.
            curl=10+5*math.sin(phase+finger*.27)
            if base in ('talking','applause_talking'):curl=13+10*math.sin(phase*2+finger*.3)
            if base.startswith('applause'):curl=2+1.2*math.sin(phase*2+finger*.2)
            if (base=='wave' or raised) and side=='R':curl=3+2*math.sin(phase*2+finger*.35)
            if base=='thinking' and side=='R':curl=5 if finger==2 else 24+3*math.sin(phase)
            for segment,factor in ((1,.65 if finger==1 else 1.),(2,1.15),(3,.65)):
                name=f'finger{finger}-{segment}.{side}'
                if name not in self._finger_axes:
                    bone=self.rig['bones'][name]
                    end=self.world(self.p[self.rig['joints'][bone['tail']]].mean(0))
                    direction=end-self.origins[name]
                    axis=np.cross(direction,palm);axis/=np.linalg.norm(axis)
                    self._finger_axes[name]=axis
                axis=self._finger_axes[name]
                angle=math.radians(curl*factor)/2
                result[name]=np.r_[axis*math.sin(angle),math.cos(angle)]
        self._finger_cache[key]=result
        return result

    def animate(self):
        sc=(self.world(self.p).max(0)[1]-self.world(self.p).min(0)[1])/1.78
        face_drivers=self.facial_drivers()
        animated=['head','jaw','spine02','spine05','eye.L','eye.R']+[n for n in self.bones if n.startswith('finger')]+[part+side for part in
          ('clavicle.','shoulder01.','upperarm01.','lowerarm01.','lowerarm02.','wrist.','upperleg01.','lowerleg01.','foot.') for side in ('L','R')]
        variants=[]
        for base in CLIPS+['applause','applause_talking']:
            for smiling in (False,True):
                for raised in ((False,) if base.startswith('applause') else (False,True)):
                    name=base+('_smile' if smiling else '')+('_right_hand_up' if raised else '')
                    variants.append((name,base,smiling,raised))
        for clip,base,smiling,raised in variants:
            duration={'idle':6.,'listening':4.,'thinking':4.2,'talking':3.6,'wave':2.4,'walk':1.2,'applause':2.4,'applause_talking':2.4}[base]
            # CGE's pinned glTF loader approximates cubic tangents by linear values.
            # Bake eased trajectories at 60 Hz, then let it interpolate quaternions.
            frames=round(duration*60)+1
            times=np.linspace(0,duration,frames)
            animation={'name':clip,'samplers':[],'channels':[]}
            def track(node,path,values,typ):
                values=np.asarray(values)
                used_times=times
                if np.max(np.abs(values-values[0]))<1e-7:
                    values=values[[0,-1]];used_times=times[[0,-1]]
                inp=self.acc(used_times,'SCALAR')
                if path=='weights':values=values.reshape(-1)
                sampler=len(animation['samplers']);animation['samplers'].append({'input':inp,'output':self.acc(values,typ),'interpolation':'LINEAR'})
                animation['channels'].append({'sampler':sampler,'target':{'node':node,'path':path}})
            rotations={name:[] for name in animated}
            root=[];morph=[]
            facial={n:[] for n in self.face_bones}
            for t in times:
                phase=2*math.pi*t/duration
                r=defaultdict(lambda:[0.,0.,0.])
                r['upperarm01.L'][2]=-25;r['upperarm01.R'][2]=25
                r['lowerarm01.L'][0]=-9;r['lowerarm01.R'][0]=-9
                r['head'][1]=1.1*math.sin(phase)+.4*math.sin(2*phase+.4)
                r['spine02'][0]=.6*math.sin(phase)
                r['spine05'][2]=.45*math.sin(phase)
                bob=.0015*math.sin(phase)*sc
                jaw=0.;blink=math.exp(-((t/duration-.72)/(.065/duration))**2)
                overrides={}
                if base=='listening':
                    r['head']=[-3+1.2*math.sin(phase)+.4*math.sin(phase*2),-3,4]
                elif base=='thinking':
                    r['head']=[6,7,2]
                    overrides.update(self.arm_ik('R',self.origins['head']+np.array([-.035,-.045,.105])*sc))
                elif base=='talking':
                    jaw=(.08+.38*math.sin(phase*5+.4)**2+.12*math.sin(phase*7)**2)*(.65+.35*math.cos(phase))
                    r['head']=[1.3*math.sin(phase*2),2*math.sin(phase),.6*math.sin(phase*3)]
                    r['upperarm01.R']=[-12-6*math.sin(phase),0,27+4*math.sin(phase)]
                    r['lowerarm01.R']=[-20-7*math.sin(phase-.4),0,0]
                    r['wrist.R']=[0,-8,4*math.sin(phase-.7)]
                elif base=='wave':
                    envelope=ease(t/.5)*(1-ease((t-1.8)/.6))
                    elbow=ease((t-.08)/.55)*(1-ease((t-1.78)/.57))
                    r['clavicle.R'][2]=-8*envelope
                    r['shoulder01.R']=[-2*envelope,0,-25*envelope]
                    r['upperarm01.R']=[-5*envelope,0,25-76*envelope]
                    r['lowerarm01.R']=[-9-8*elbow,0,-42*elbow]
                    r['wrist.R'][2]=15*math.sin(2*math.pi*(t-.45)/.65)*ease((t-.5)/.2)*(1-ease((t-1.65)/.25))
                    r['head'][2]=-2*envelope
                elif base=='walk':
                    bob=(-.012+.006*math.cos(2*phase))*sc
                    for side,sign in [('L',1),('R',-1)]:
                        u=(t/duration+(0 if side=='L' else .5))%1
                        thigh,shin,foot=self.leg_ik(side,u,bob)
                        r['upperleg01.'+side][0]=thigh;r['lowerleg01.'+side][0]=shin;r['foot.'+side][0]=foot
                        r['upperarm01.'+side][0]=-sign*10*math.cos(phase+.15)
                        r['lowerarm01.'+side][0]=-12-sign*3*math.cos(phase-.2)
                    r['spine05'][1]=2*math.sin(phase);r['spine02'][1]=-1.5*math.sin(phase)
                elif base.startswith('applause'):
                    envelope=ease(t/.45)*(1-ease((t-1.85)/.55))
                    spacing=.012+.065*math.sin(math.pi*(t-.45)/.48)**2
                    chest=self.origins['spine01']
                    for side,sign in [('L',1),('R',-1)]:
                        ik=self.arm_ik(side,chest+np.array([sign*spacing,.03,.24])*sc,[sign*.6,-1.2,.05])
                        for name,q in ik.items():overrides[name]=qblend(quat(*r[name]),q,envelope)
                        twist,wrist=self.clap_wrist(side,ik)
                        overrides['lowerarm02.'+side]=qblend(quat(),twist,envelope)
                        overrides['wrist.'+side]=qblend(quat(),wrist,envelope)
                    r['head'][0]=-2*envelope
                    if base=='applause_talking':jaw=.12+.32*math.sin(phase*5)**2
                if raised:
                    ik=self.arm_ik('R',self.origins['head']+(np.array([-.17,.20,.09])+np.array([.002*math.sin(phase),.003*math.cos(phase),0]))*sc,shoulder_elevation=1.)
                    overrides.update(ik);r['wrist.R']=[0,-10,2*math.sin(phase)]
                # Positive X opens downward/backward about the mandibular hinge.
                # Upper teeth remain head-bound; lower teeth follow the jaw skin.
                r['jaw'][0]=22*jaw
                gaze=3.5*math.sin(phase)+1.2*math.sin(phase*3)
                for side in ('L','R'):
                    r['eye.'+side]=[1.5*math.sin(phase*2),gaze,0]
                    overrides.update(self.finger_pose(side,phase,base,raised))
                expression=np.array([jaw,blink,.35 if smiling else .04])
                offsets=np.einsum('e,ebc->bc',expression,face_drivers)
                for name,offset in zip(self.face_bones,offsets):
                    parent=self.rig['bones'][name]['parent']
                    ancestor=parent
                    while ancestor and ancestor!='jaw':ancestor=self.rig['bones'][ancestor]['parent']
                    if ancestor=='jaw':offset=qrotate(qinverse(quat(*r['jaw'])),offset)
                    rest=self.origins[name]-self.origins[parent]
                    facial[name].append(rest+offset)
                for name in animated:
                    rotations[name].append(overrides[name] if name in overrides else (quat(*r[name]) if name in r else [0,0,0,1]))
                root.append(self.doc['nodes'][self.bone_nodes['root']]['translation']+np.array([0,bob,0]))
                # Reference morphs are retained for authoring, but remain zero:
                # the skeletal fallback must not double the expression elsewhere.
                morph.append([0,0,0])
            # Reset every joint that any clip moves. The other joints stay
            # in bind pose, so duplicating their constant tracks only burdens CGE.
            for name in animated:track(self.bone_nodes[name],'rotation',rotations[name],'VEC4')
            for name in self.face_bones:track(self.bone_nodes[name],'translation',facial[name],'VEC3')
            track(self.bone_nodes['root'],'translation',root,'VEC3')
            track(self.face_node,'weights',morph,'SCALAR')
            self.doc['animations'].append(animation)

def main():
    import argparse
    p=argparse.ArgumentParser(__doc__);p.add_argument('--profile',choices=list(PROFILES));args=p.parse_args()
    for profile in ([args.profile] if args.profile else PROFILES): Avatar(profile).build()

if __name__=='__main__': main()
