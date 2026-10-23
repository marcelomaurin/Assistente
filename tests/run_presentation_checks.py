"""Exercise real PVA export/import and hostile ZIPs without network or credentials."""
from pathlib import Path
import argparse, hashlib, json, struct, subprocess, tempfile, warnings, zipfile

def run(tool, *args, ok=True):
    p=subprocess.run([str(tool),*map(str,args)],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=30)
    assert p.returncode==(0 if ok else 1), (args,p.returncode,p.stdout,p.stderr)
    return p.stdout+p.stderr

def main():
    ap=argparse.ArgumentParser();ap.add_argument('tool',type=Path);a=ap.parse_args();tool=a.tool.resolve()
    print(run(tool,'selftest').strip())
    with tempfile.TemporaryDirectory(prefix='pva-tests-') as tmp:
        root=Path(tmp)/'ação com espaços';root.mkdir();(root/'assets').mkdir();(root/'assets/figura.png').write_bytes(b'image-fixture')
        (root/'assets/som.wav').write_bytes(b'audio-fixture')
        (root/'assets/nao-usado.png').write_bytes(b'unused')
        script='[avatar=professor][voz=nova][sorriso] Olá! [abrir arquivo=assets/figura.png] Imagem.[abrir arquivo=assets/som.wav|inicio=00:00:01][fechar som][fechar arquivo]'
        source=root/'roteiro.txt';source.write_text(script,encoding='utf-8')
        valid=root/'valid.pva';run(tool,'pack',source,root,valid);run(tool,'verify',valid,root/'extraido')
        assert (root/'extraido/script.txt').read_bytes()==script.encode()
        with zipfile.ZipFile(valid) as z:
            entries={n:z.read(n) for n in z.namelist()}
        assert set(entries)=={'manifest.json','script.txt','assets/figura.png','assets/som.wav'},set(entries)
        manifest=json.loads(entries['manifest.json'])
        for f in manifest['files']:
            assert hashlib.sha256(entries[f['path']]).hexdigest()==f['sha256']
        cases=0
        def reject(label,items,transform=None):
            nonlocal cases
            bad=root/(label+'.pva')
            with warnings.catch_warnings():
                warnings.simplefilter('ignore')
                with zipfile.ZipFile(bad,'w',compression=zipfile.ZIP_DEFLATED) as z:
                    for n,data in items:z.writestr(n,data)
            if transform:bad.write_bytes(transform(bad.read_bytes()))
            dest=root/(label+'-extract')
            run(tool,'verify',bad,dest,ok=False);assert not dest.exists(),label;cases+=1
        base=list(entries.items())
        for n in ['../escape.png','assets/../../escape.png','C:/escape.png','/escape.png','assets/CON.png','assets/x:ads','assets/x.','assets/x ','assets//x','assets\\x.png']:
            reject('path-'+str(cases),base+[(n,b'x')])
        reject('duplicate',base+[('script.txt',entries['script.txt'])])
        reject('case-duplicate',base+[('SCRIPT.TXT',entries['script.txt'])])
        reject('hash-tamper',[(n,b'tampered' if n=='script.txt' else b) for n,b in base])
        reject('missing-file',[(n,b) for n,b in base if n!='assets/figura.png'])
        reject('extra-file',base+[('assets/extra.png',b'x')])
        def changed_manifest(**changes):
            m=dict(manifest);m.update(changes)
            return [(n,json.dumps(m).encode() if n=='manifest.json' else b) for n,b in base]
        reject('future-version',changed_manifest(version=2))
        reject('wrong-format',changed_manifest(format='other'))
        reject('bad-json',[(n,b'{' if n=='manifest.json' else b) for n,b in base])
        reject('non-object',[(n,b'[]' if n=='manifest.json' else b) for n,b in base])
        reject('wrong-files-type',changed_manifest(files={}))
        def forged_size(data):
            data=bytearray(data);i=data.index(b'PK\x01\x02');struct.pack_into('<I',data,i+24,64*1024*1024+1);return data
        reject('oversized-entry',base,forged_size)
        # A dangerous local header must not bypass the safe central directory.
        def local_traversal(data):
            data=bytearray(data);i=data.index(b'PK\x03\x04');n=struct.unpack_from('<H',data,i+26)[0]
            data[i+30:i+30+n]=b'../'+b'x'*(n-3);return data
        reject('local-header-traversal',base,local_traversal)
        for bad in ['[abrir arquivo=../x.png]','[ir para slide=0]','[avatar=]','[voz=]','[abrir arquivo=assets/som.wav|inicio=00:60:00]','[abrir arquivo=assets/figura.png|inicio=00:00:01]','[articulacao=jaw,y,1,1000,linear]','[abrir arquivo=assets/figura.png][abrir arquivo=assets/FIGURA.png]']:
            source.write_text(bad,encoding='utf-8');run(tool,'pack',source,root,root/'bad.pva',ok=False)
        # Existing extraction targets must never be overwritten.
        run(tool,'verify',valid,root/'extraido',ok=False)
        print(f'PASS: UTF-8 roundtrip, referenced resources only, SHA256 inventory, {cases} hostile ZIP cases, invalid tags, extraction ownership')
if __name__=='__main__':main()
