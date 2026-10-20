# Fontes gráficas dos avatares v3

São dados artísticos CC0, não código do aplicativo MakeHuman. O gerador do
Assistente lê OBJ, deltas de anatomia/idade, mapeamentos de roupa, esqueleto,
pesos e texturas diretamente. Não importa módulos Python do MakeHuman.

## Proveniência

Malha, alvos, rig e pesos: repositório oficial
https://github.com/makehumancommunity/makehuman,
commit `a8bc2d54ff0ac92e78ff71431b1023eda42bf482`.

- `makehuman/data/3dobjs/base.obj`
- `makehuman/data/rigs/default.mhskel`
- `makehuman/data/rigs/default_weights.mhw`
- `makehuman/data/targets/macrodetails/*.target` (somente os nomes presentes aqui)
- `makehuman/data/targets/expression/units/caucasian/mouth-open.target`
- `LICENSE.md` e `LICENSE.ASSETS.md` originais, preservados nesta pasta.

Roupas, cabelo, olhos, sobrancelhas, dentes e peles em `system/`:
pacote oficial **MakeHuman system assets**, inteiramente CC0,
https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html.
URL e SHA-256 do arquivo de origem, hashes por arquivo e preparação das
texturas constam em `system-assets.lock.json`. As imagens foram reduzidas
para no máximo 2048 px (pele) ou 1024 px (outros recursos), mantendo alfa.
Os arquivos de mapeamento preservam os autores e a declaração CC0.

A licença do programa MakeHuman é distinta da licença dos recursos gráficos;
`LICENSE.md` oficial explica a divisão. O aplicativo MakeHuman não é empacotado.

## Reprodução

Com Python, numpy e Pillow (`pip install -r tools/avatar-requirements.txt`):

```powershell
python tools/generate_professor.py
```

As fontes preparadas estão incluídas, portanto a geração não usa rede.
Para preparar de novo o pacote oficial original, baixe a URL registrada no
lock e execute `python tools/prepare_avatar_sources.py --archive caminho.zip`.
O script exige o SHA-256 exato antes de ler o conteúdo.

## Adaptação

O gerador aplica os alvos de idade/anatomia, ajusta roupas/cabelo por
coordenadas baricêntricas e transfere pesos. Exporta quatro influências
normalizadas por vértice, matrizes inversas da pose de vínculo, hierarquia
com 163 juntas, normais suaves, UVs, materiais PBR e recorte alfa no cabelo.
Só rosto/pescoço e mãos da malha de pele são exportados; tronco e pelve são
cobertos por vestuário próprio, inclusive nos modelos criança e bebê.

As seis animações e os acessórios novos são autoria do Assistente, CC0.
`jawOpen` e `blink` são morph targets animados; abertura de boca é genérica,
sem visemas ou sincronização por fonema. O bebê usa um alvo de anatomia
infantil, sem ser uma cópia reduzida do corpo adulto.
