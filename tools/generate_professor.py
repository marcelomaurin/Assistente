"""Original articulated glTF avatars; standard library only, deterministic.
Meshes, facial details, hands, clothes, texture and animation are authored here.
No image is used as a billboard, and no external model is downloaded.
"""
import base64
import json
import math
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1] / 'AVATARES'
PROFILES = [('professor','Professor'),('medico','Médico'),('engenheiro','Engenheiro'),
            ('programador','Programador'),('dona_de_casa','Dona de casa'),
            ('empresario','Empresário'),('padre','Padre'),('crianca','Criança'),
            ('bebe','Bebê'),('robo','Robô')]


def argyle(path):
    raw = bytearray()
    for y in range(256):
        raw.append(0)
        for x in range(256):
            dx, dy = abs((x % 128)-64)/64, abs((y % 128)-64)/64
            d = dx+dy
            c = (198,203,186) if d < .92 else (38,78,103)
            if abs(d-1) < .025: c = (130,157,165)
            if (x+y) % 5 == 0: c = tuple(max(0,v-6) for v in c)
            raw.extend(c)
    def chunk(kind, body):
        return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)&0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',256,256,8,2,0,0,0))+
                     chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))


def create(profile, label):
    folder = ROOT/profile
    folder.mkdir(parents=True,exist_ok=True)
    doc = {'asset':{'version':'2.0','generator':'Assistente original detailed avatar v2'},
           'scene':0,'scenes':[{'nodes':[0]}],'nodes':[],'meshes':[],'materials':[],
           'bufferViews':[],'accessors':[],'animations':[], 'extensionsUsed':['KHR_materials_unlit']}
    binary = bytearray()
    def acc(values, typ, width, indices=False):
        while len(binary)%4: binary.append(0)
        start=len(binary)
        for row in values: binary.extend(struct.pack('<'+('H' if indices else 'f')*width,*row))
        view=len(doc['bufferViews'])
        doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(binary)-start})
        a={'bufferView':view,'componentType':5123 if indices else 5126,'count':len(values),'type':typ}
        if not indices:
            a['min']=[min(v[i] for v in values) for i in range(width)]
            a['max']=[max(v[i] for v in values) for i in range(width)]
        doc['accessors'].append(a)
        return len(doc['accessors'])-1
    def material(name,color,rough=.65,metal=0):
        p={'baseColorFactor':list(color[:3])+[color[3] if len(color)>3 else 1],
           'roughnessFactor':rough,'metallicFactor':metal}
        m={'name':name,'pbrMetallicRoughness':p,'doubleSided':True}
        if len(color)>3: m.update(alphaMode='BLEND')
        doc['materials'].append(m)
        return len(doc['materials'])-1
    palette = {'cloth':[.12,.32,.43],'shirt':[.80,.89,.92],'pants':[.055,.14,.22],
               'skin':[.88,.59,.41],'cheek':[.85,.49,.36],'hair':[.18,.075,.035],
               'strand':[.29,.13,.067],'white':[.94,.95,.95],'dark':[.025,.033,.042],
               'iris':[.24,.12,.055],'pupil':[.008,.009,.012],'lip':[.32,.11,.09],
               'gold':[.84,.59,.19],'cyan':[.05,.65,.72],'shadow':[.94,.94,.94],
               'tongue':[.80,.29,.30],'glass':[.82,.95,1,.14]}
    if profile=='medico': palette.update(cloth=[.92,.95,.96],shirt=[.18,.54,.58])
    if profile=='engenheiro': palette.update(cloth=[.9,.53,.06],shirt=[.82,.86,.87])
    if profile=='programador': palette.update(cloth=[.21,.15,.36],skin=[.66,.38,.22])
    if profile=='dona_de_casa': palette.update(cloth=[.77,.50,.13],shirt=[.92,.92,.85],skin=[.63,.35,.19])
    if profile=='empresario': palette.update(cloth=[.07,.10,.15],shirt=[.9,.92,.96])
    if profile=='padre': palette.update(cloth=[.025,.03,.04],shirt=[.93,.93,.93],hair=[.39,.40,.39])
    if profile=='crianca': palette.update(cloth=[.92,.52,.08],shirt=[.2,.48,.55])
    if profile=='bebe': palette.update(cloth=[.46,.75,.83],pants=[.46,.75,.83],skin=[.79,.48,.29])
    if profile=='robo': palette.update(cloth=[.87,.9,.91],shirt=[.03,.04,.05],skin=[.86,.89,.9],
                                       cheek=[.82,.86,.88],iris=[.04,.73,.72],lip=[.43,.49,.5],pants=[.03,.04,.05])
    mats={k:material(k,v,.28 if k in ['glass','iris','pupil'] else .65,.25 if profile=='robo' and k in ['cloth','skin'] else 0)
          for k,v in palette.items()}
    doc['materials'][mats['shadow']]['extensions']={'KHR_materials_unlit':{}}
    if profile=='professor':
        argyle(folder/'roupa.png')
        doc['images']=[{'uri':'roupa.png'}]
        doc['textures']=[{'source':0,'sampler':0}]
        doc['samplers']=[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}]
        doc['materials'][mats['cloth']]['pbrMetallicRoughness'].update(baseColorFactor=[1,1,1,1],baseColorTexture={'index':0})
    geo={}
    for kind in ['sphere','cap','body','torus','box']:
        positions=[]; normals=[]; uv=[]; triangles=[]
        if kind=='box':
            # Bevelled cube, using a sphere projected to rounded cube faces.
            for axis,sign in [(0,-1),(0,1),(1,-1),(1,1),(2,-1),(2,1)]:
                others=[i for i in range(3) if i!=axis]
                for yi in range(7):
                    for xi in range(7):
                        p=[0.,0.,0.];p[axis]=sign*.5;p[others[0]]=-.5+xi/6;p[others[1]]=-.5+yi/6
                        c=[max(-.34,min(.34,v)) for v in p]
                        n=[p[i]-c[i] for i in range(3)]; ln=math.sqrt(sum(v*v for v in n));n=[v/ln for v in n]
                        positions.append([c[i]+.16*n[i] for i in range(3)]);normals.append(n);uv.append([xi/6,yi/6])
                start=len(positions)-49
                for y in range(6):
                    for x in range(6):
                        a=start+y*7+x
                        triangles.extend([(a,a+1,a+8),(a,a+8,a+7)])
        else:
            rows,cols=(28,40) if kind!='torus' else (12,48)
            for y in range(rows+1):
                t=y/rows
                for x in range(cols+1):
                    u=x/cols; theta=u*math.tau
                    if kind=='torus':
                        phi=t*math.tau; r=.42+.075*math.cos(phi)
                        p=[r*math.cos(theta),r*math.sin(theta),.075*math.sin(phi)]
                        n=[math.cos(phi)*math.cos(theta),math.cos(phi)*math.sin(theta),math.sin(phi)]
                    elif kind=='body':
                        r=.30+.18*math.sin(math.pi*t)**.55
                        p=[r*math.cos(theta),t-.5,r*math.sin(theta)]
                        slope=.18*.55*math.pi*math.cos(math.pi*t)*max(.001,math.sin(math.pi*t))**(-.45)
                        n=[math.cos(theta),-slope,math.sin(theta)];ln=math.sqrt(sum(v*v for v in n));n=[v/ln for v in n]
                    else:
                        phi=(-math.pi/2+t*math.pi) if kind=='sphere' else t*math.pi/2
                        n=[math.cos(phi)*math.cos(theta),math.sin(phi),math.cos(phi)*math.sin(theta)]
                        p=[v*.5 for v in n]
                    positions.append(p);normals.append(n);uv.append([u,t])
            for y in range(rows):
                for x in range(cols):
                    a=y*(cols+1)+x
                    triangles.extend([(a,a+1,a+cols+2),(a,a+cols+2,a+cols+1)])
        # Orient triangles against outward normals; no lighting depends on back-face guesses.
        idx=[]
        for tri in triangles:
            a,b,c=[positions[i] for i in tri];ab=[b[i]-a[i] for i in range(3)];ac=[c[i]-a[i] for i in range(3)]
            cross=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
            if sum(cross[i]*normals[tri[0]][i] for i in range(3))<0: tri=tuple(reversed(tri))
            idx.extend([[i] for i in tri])
        geo[kind]={'attributes':{'POSITION':acc(positions,'VEC3',3),'NORMAL':acc(normals,'VEC3',3),'TEXCOORD_0':acc(uv,'VEC2',2)},
                   'indices':acc(idx,'SCALAR',1,True)}
    meshes={}
    def mesh(kind,mat):
        key=(kind,mat)
        if key not in meshes:
            primitive=dict(geo[kind]);primitive['material']=mats[mat]
            meshes[key]=len(doc['meshes']);doc['meshes'].append({'primitives':[primitive]})
        return meshes[key]
    def node(name,parent=None,p=(0,0,0),size=None,kind='sphere',mat='skin',rot=None):
        n={'name':name,'translation':list(p)}
        if size: n.update(scale=list(size),mesh=mesh(kind,mat))
        if rot is not None: n['rotation']=rot
        i=len(doc['nodes']);doc['nodes'].append(n)
        if parent is not None: doc['nodes'][parent].setdefault('children',[]).append(i)
        return i
    def quat(axis,degrees):
        a=math.radians(degrees)/2
        return [math.sin(a) if i==axis else 0 for i in range(3)]+[math.cos(a)]
    root=node(label)
    if profile in ['crianca','bebe']: doc['nodes'][root]['scale']=[.74 if profile=='crianca' else .52]*3
    node('Contact shadow',root,(0,.018,0),(.85,.012,.48),mat='shadow')
    hips=node('Hips',root,(0,.98,0))
    node('Trousers',hips,(0,-.035,0),(.40,.23,.28),'body','pants')
    torso=node('Torso',hips,(0,.10,0))
    node('Tailored clothing',torso,(0,.28,0),(.51,.62,.31),'body','cloth')
    node('Shirt placket',torso,(0,.34,.145),(.13,.47,.018),'box','shirt')
    for side in [-1,1]:
        node('Collar',torso,(side*.07,.55,.14),(.13,.13,.03),'box','shirt',quat(2,side*25))
    if profile!='professor':
        for y in [.13,.24,.35,.46]: node('Button',torso,(0,y,.163),(.018,.018,.012),mat='gold')
    node('Neck',torso,(0,.64,0),(.13,.17,.13),mat='skin')
    head=node('Head',torso,(0,.69,0))
    if profile in ['bebe','crianca']:doc['nodes'][head]['scale']=[1.45 if profile=='bebe' else 1.15]*3
    node('Face',head,(0,.21,0),(.42,.49,.35),mat='skin')
    node('Chin',head,(0,.04,.04),(.26,.16,.23),mat='skin')
    for side in [-1,1]:
        node('Ear',head,(side*.22,.23,0),(.075,.13,.065),mat='skin')
        node('Inner ear',head,(side*.244,.23,.024),(.032,.08,.035),mat='cheek')
        node('Cheek',head,(side*.12,.155,.139),(.09,.065,.035),mat='cheek')
    eyes=[]
    glasses=profile in ['professor','medico','programador','dona_de_casa']
    for side in [-1,1]:
        eye=node('Eye',head,(side*.09,.27,.157));eyes.append(eye)
        node('Sclera',eye,(0,0,0),(.145,.12,.064),mat='white')
        node('Iris',eye,(0,0,.033),(.069,.077,.019),mat='iris')
        node('Pupil',eye,(0,0,.045),(.030,.043,.014),mat='pupil')
        node('Catchlight',eye,(-.012,.014,.052),(.014,.016,.008),mat='white')
        for x in range(6):
            node('Sculpted eyebrow',head,(side*(.045+x*.018),.355+.012*math.sin(x/5*math.pi),.155),(.035,.027,.022),mat='hair' if profile!='robo' else 'dark')
        if glasses: node('Round frame',head,(side*.09,.27,.226),(.177,.158,.15),'torus','dark')
    if glasses:
        node('Bridge',head,(0,.278,.232),(.035,.014,.014),'box','dark')
        for side in [-1,1]:node('Temple',head,(side*.19,.28,.11),(.014,.014,.24),'box','dark')
    node('Nose',head,(0,.192,.177),(.072,.105,.087),mat='skin')
    for side in [-1,1]:node('Nostril',head,(side*.021,.161,.213),(.021,.013,.014),mat='lip')
    mouth=node('Mouth',head,(0,.088,.151))
    node('Smile',mouth,(0,0,0),(.164,.076,.037),mat='lip')
    node('Teeth',mouth,(0,.016,.021),(.132,.025,.012),mat='white')
    node('Tongue',mouth,(0,-.019,.019),(.073,.018,.012),mat='tongue')
    if profile!='robo':
        node('Hair cap',head,(0,.405,-.025),(.47,.23,.40),'cap','hair')
        for i in range(9):
            node('Swept hair strand',head,(-.15+i*.035,.445+.024*math.sin(i*.4),.065),(.10,.11,.27),mat='strand' if i%3==0 else 'hair',rot=quat(2,22))
        for side in [-1,1]: node('Sideburn',head,(side*.19,.315,-.014),(.055,.18,.15),mat='hair')
    shoulders=[]; elbows=[]; wrists=[]; legs=[]; knees=[]
    for side in [-1,1]:
        shoulder=node('Shoulder',torso,(side*.278,.48,0));shoulders.append(shoulder)
        node('Upper sleeve',shoulder,(side*.015,-.135,0),(.17,.30,.19),mat='shirt' if profile=='professor' else 'cloth')
        elbow=node('Elbow',shoulder,(side*.02,-.26,0));elbows.append(elbow)
        node('Forearm',elbow,(0,-.125,0),(.115,.27,.13),mat='skin' if profile in ['professor','bebe','robo'] else 'cloth')
        node('Rolled cuff',elbow,(0,-.015,0),(.16,.075,.18),'body','shirt')
        wrist=node('Wrist',elbow,(0,-.267,0));wrists.append(wrist)
        node('Palm',wrist,(0,-.038,0),(.091,.11,.05),mat='skin')
        for finger in range(4):
            x=(finger-1.5)*.021;length=[.066,.082,.077,.058][finger]
            node('Finger proximal',wrist,(x,-.10,0),(.021,length,.025),mat='skin')
            node('Fingertip',wrist,(x,-.10-length*.46,0.002),(.019,.035,.023),mat='skin')
        node('Thumb',wrist,(-side*.052,-.054,.012),(.026,.075,.03),mat='skin',rot=quat(2,side*28))
        hip=node('Hip',hips,(side*.115,-.10,0));legs.append(hip)
        node('Thigh',hip,(0,-.19,0),(.18,.42,.23),mat='pants')
        knee=node('Knee',hip,(0,-.40,0));knees.append(knee)
        node('Trouser leg',knee,(0,-.16,0),(.152,.37,.20),'body','pants')
        node('Sneaker',knee,(0,-.365,.055),(.205,.13,.32),mat='white' if profile in ['professor','medico','crianca','bebe','robo'] else 'dark')
        node('Sole',knee,(0,-.417,.06),(.21,.035,.33),'box','white')
        for i in range(3):node('Shoe lace',knee,(0,-.325,.09+i*.027),(.11,.012,.016),'box','shirt')
    if profile=='medico':
        node('Stethoscope loop',torso,(0,.37,.18),(.24,.34,.13),'torus','dark')
        node('Stethoscope head',torso,(.11,.19,.20),(.067,.067,.025),mat='gold')
        node('Name badge',torso,(-.17,.37,.17),(.08,.10,.012),'box','white')
    if profile=='engenheiro':
        node('Hard hat',head,(0,.43,-.01),(.51,.28,.44),'cap','gold')
        node('Helmet brim',head,(0,.43,.035),(.57,.025,.50),mat='gold')
        for side in [-1,1]:node('Reflective tape',torso,(side*.16,.29,.15),(.035,.49,.017),'box','white')
    if profile=='programador':
        node('Hood',torso,(0,.53,-.11),(.38,.19,.24),mat='cloth')
        node('Laptop',torso,(0,.04,.29),(.40,.24,.025),'box','dark')
        node('Laptop display',torso,(0,.04,.308),(.36,.20,.012),'box','cyan')
        for i in range(3):node('Code line',torso,(-.045,.08-i*.036,.317),(.16+i*.025,.012,.006),'box','white')
    if profile=='dona_de_casa':
        for side in [-1,1]:
            for i in range(5):node('Wavy bob',head,(side*(.20+.012*math.sin(i)),.32-i*.065,-.015),(.16,.15,.26),mat='hair' if i%2 else 'strand')
        node('Apron',torso,(0,.17,.16),(.34,.38,.022),'body','shirt')
        node('Apron pocket',torso,(0,.1,.18),(.18,.10,.016),'box','cloth')
    if profile=='empresario':
        node('Tie',torso,(0,.35,.167),(.052,.31,.019),'body','lip')
        node('Briefcase',wrists[0],(0,-.24,0),(.32,.28,.12),'box','dark')
        node('Briefcase handle',wrists[0],(0,-.09,0),(.13,.08,.1),'torus','gold')
    if profile=='padre':
        node('Cassock',hips,(0,-.26,0),(.49,.80,.34),'body','cloth')
        node('Clerical collar',torso,(0,.56,.16),(.095,.04,.026),'box','white')
        node('Cross',torso,(0,.34,.18),(.018,.14,.018),'box','gold')
        node('Crossbar',torso,(0,.365,.18),(.082,.018,.018),'box','gold')
    if profile=='crianca':
        node('Cap',head,(0,.43,-.02),(.49,.17,.41),'cap','cloth')
        node('Cap visor',head,(0,.435,.19),(.37,.028,.26),mat='cloth')
    if profile=='bebe':
        node('Bib',torso,(0,.39,.16),(.31,.31,.03),mat='white')
        node('Pacifier',head,(0,.095,.197),(.12,.075,.03),mat='cyan')
        node('Pacifier ring',head,(0,.065,.228),(.055,.06,.08),'torus','gold')
    if profile=='robo':
        for i in range(5):node('Neck ring',torso,(0,.59+i*.026,0),(.15,.016,.15),mat='dark')
        for side in [-1,1]:
            node('Ear cup',head,(side*.253,.27,-.012),(.075,.24,.19),mat='dark')
            node('Ear cup inset',head,(side*.29,.27,-.012),(.022,.18,.13),mat='cyan')
            node('Arm cyan inlay',elbows[0 if side<0 else 1],(0,-.13,.067),(.07,.20,.016),mat='cyan')
            node('Mechanical shoulder',shoulders[0 if side<0 else 1],(side*.025,-.015,0),(.19,.16,.21),mat='dark')
            node('Chest plate',torso,(side*.105,.35,.126),(.23,.36,.095),mat='cloth')
        for i in range(20):
            angle=i/19*math.pi
            node('Headset band',head,(.26*math.cos(angle),.29+.28*math.sin(angle),-.055),(.065,.055,.08),mat='dark')
        for i in range(7):node('Boom microphone',head,(-.24+i*.024,.18-i*.012,.07+i*.02),(.025,.03,.04),mat='dark')
        node('Microphone capsule',head,(-.08,.108,.21),(.065,.04,.04),mat='dark')
    animated=[torso,head]+shoulders+elbows+wrists+legs+knees
    def rotate(target,axis,values):return target,'rotation',[quat(axis,v) for v in values]
    def clip(name,duration,changes):
        tracks={(n,'rotation'):[[0,0,0,1],[0,0,0,1]] for n in animated}
        tracks[(hips,'translation')]=[[0,.98,0],[0,.98,0]]
        tracks[(mouth,'scale')]=[[1,1,1],[1,1,1]]
        for eye in eyes:tracks[(eye,'scale')]=[[1,1,1],[1,1,1]]
        for n,path,values in changes:tracks[(n,path)]=values
        animation={'name':name,'samplers':[],'channels':[]}
        for (n,path),values in tracks.items():
            inp=acc([[duration*i/(len(values)-1)] for i in range(len(values))],'SCALAR',1)
            output=acc(values,'VEC4' if path=='rotation' else 'VEC3',len(values[0]))
            sampler=len(animation['samplers']);animation['samplers'].append({'input':inp,'output':output,'interpolation':'LINEAR'})
            animation['channels'].append({'sampler':sampler,'target':{'node':n,'path':path}})
        doc['animations'].append(animation)
    clip('idle',4.2,[(hips,'translation',[[0,.98,0],[0,.991,0],[0,.98,0]])]+[(e,'scale',[[1,v,1] for v in [1,1,1,1,1,1,.08,1,1]]) for e in eyes])
    clip('listening',2.4,[rotate(head,2,[-7,-3,-7]),rotate(elbows[1],0,[-20,-25,-20])])
    clip('thinking',2.4,[rotate(head,0,[8,13,8]),rotate(shoulders[1],0,[-50,-55,-50]),rotate(elbows[1],0,[-80,-85,-80])])
    clip('talking',1.2,[(mouth,'scale',[[1,1,1],[1,1.65,1],[1,.7,1],[1,1.3,1],[1,1,1]]),rotate(shoulders[0],0,[-12,-22,-12]),rotate(head,1,[-3,3,-3])])
    clip('wave',2.4,[rotate(shoulders[0],2,[0,-115,-115,-115,-115,0]),rotate(elbows[0],2,[0,-35,-15,-42,-20,0]),rotate(wrists[0],2,[0,-12,12,-12,12,0])])
    clip('walk',1.2,[rotate(legs[0],0,[-24,24,-24]),rotate(legs[1],0,[24,-24,24]),rotate(knees[0],0,[0,18,0]),rotate(knees[1],0,[18,0,18]),rotate(shoulders[0],0,[20,-20,20]),rotate(shoulders[1],0,[-20,20,-20]),(hips,'translation',[[0,.98,0],[0,.995,0],[0,.98,0]])])
    doc['buffers']=[{'byteLength':len(binary),'uri':'data:application/octet-stream;base64,'+base64.b64encode(binary).decode()}]
    (folder/'modelo.gltf').write_text(json.dumps(doc,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
    (folder/'modelo.ini').write_text('[animations]\n'+'\n'.join(f'{a}={a}' for a in ['idle','listening','thinking','talking','wave','walk'])+'\n',encoding='utf-8')
    (folder/'avatar.json').write_text(json.dumps({'id':profile,'name':label,'model':'modelo.gltf','license':'CC0-1.0'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(profile,len(doc['nodes']),'nodes',len(binary),'buffer bytes')


if __name__=='__main__':
    for pid,name in PROFILES:create(pid,name)
