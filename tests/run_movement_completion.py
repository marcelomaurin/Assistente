"""Require all 53 bundled JSON movements to finish, independently and in sequence.
Run from repository root after building movement_completion_probe.lpr.
"""
from pathlib import Path
import argparse,json,os,subprocess,concurrent.futures
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--probe',type=Path,default=ROOT/'build/movement-v2/movement_completion_probe.exe');p.add_argument('--profiles',nargs='*');p.add_argument('--out',type=Path,default=ROOT/'build/movement-completion-0213');a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
 models=sorted((ROOT/'AVATARES').glob('*/modelo.gltf'))
 if a.profiles:models=[m for m in models if m.parent.name in a.profiles]
 def check(item):
  model,mode=item;name=model.parent.name;d=json.loads(model.read_text(encoding='utf-8'));attrs=[d['accessors'][p['attributes']['POSITION']] for m in d['meshes'] for p in m['primitives']];height=max(v['max'][1] for v in attrs)-min(v['min'][1] for v in attrs)
  result=subprocess.run([str(a.probe.resolve()),name,str(height),mode],cwd=ROOT,env=dict(os.environ,ASSISTENTE_MOVEMENTS_FILE=str(ROOT/'AVATARES/movimentos.json')),capture_output=True,timeout=240)
  text=(result.stdout+result.stderr).decode('utf-8',errors='replace');(a.out/f'{name}-{mode}.log').write_text(text,encoding='utf-8')
  passed=result.returncode==0 and f'PROFILE {name} incomplete=0' in text
  print(('PASS' if passed else 'FAIL'),name,mode,flush=True)
  if not passed:print(text,flush=True)
  return {'avatar':name,'mode':mode,'passed':passed,'count':53}
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(check,[(m,mode) for m in models for mode in ['fresh','sequence']]))
 report={'passed':all(r['passed'] for r in results),'executions':sum(r['count'] for r in results),'cases':results}
 (a.out/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 if not report['passed']:raise SystemExit(1)
 print('PASS:',report['executions'],'complete movements with active collision protection',flush=True)
if __name__=='__main__':main()
