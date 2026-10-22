"""Check Markdown file links and heading anchors, including filename case for GitHub."""
import json,re,unicodedata
from pathlib import Path
from urllib.parse import unquote
ROOT=Path(__file__).resolve().parents[1]

def heading_ids(path):
    ids=set();seen={};fence=False
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        if line.strip().startswith('```'):fence=not fence;continue
        if fence:continue
        if not re.match(r'^#{1,6}\s',line):continue
        value=re.sub(r'^#+\s*','',line).strip().lower()
        value=''.join(c for c in value if c in '-_ ' or unicodedata.category(c)[0] in 'LN')
        value=value.replace(' ','-');n=seen.get(value,0);seen[value]=n+1
        ids.add(value if n==0 else value+'-'+str(n))
    return ids

def exact_case(path):
    relative=path.relative_to(ROOT);current=ROOT
    for part in relative.parts:
        assert part in [p.name for p in current.iterdir()],f'Filename case mismatch: {path}'
        current=current/part

def main():
    files=[ROOT/'README.md',*(ROOT/'Docs').rglob('*.md'),*(ROOT/'sdk').rglob('*.md'),*(ROOT/'bin/integration').rglob('*.md')]
    links=0
    for source in files:
        text=source.read_text(encoding='utf-8-sig')
        for match in re.finditer(r'(?<!!)\[[^\]\n]+\]\(([^)\n]+)\)',text):
            href=unquote(match[1]).strip('<>')
            if re.match(r'[a-zA-Z][a-zA-Z0-9+.-]*:',href):continue
            target,_,anchor=href.partition('#');destination=(source.parent/target).resolve() if target else source
            assert destination.is_relative_to(ROOT),f'Link escapes repository: {source}: {href}'
            assert destination.exists(),f'Broken link: {source}: {href}'
            exact_case(destination)
            if anchor and destination.suffix.lower()=='.md':
                assert anchor in heading_ids(destination),f'Broken heading: {source}: {href}'
            links+=1
    result={'result':'PASS','markdown_files':len(files),'local_links':links,'checks':['local file existence','GitHub filename case','Markdown heading anchors']}
    out=ROOT/'build/integration';out.mkdir(parents=True,exist_ok=True)
    (out/'documentation-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()
