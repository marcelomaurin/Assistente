# Criador Avatar

Programa do Assistente para criar e importar avatares 3D. Funciona como uma versão simplificada do MakeHuman, integrada ao Assistente: o avatar gerado já sai com o esqueleto de 163 juntas, as 65 animações, os 53 movimentos calibrados (com proteção de colisão) e aparece na lista de avatares do Assistente.

Atalho no menu Iniciar: **Criador Avatar do Assistente** (`criador_avatar.exe`).

## Abas

| Aba | O que ajusta |
| --- | --- |
| Corpo | Gênero, idade, músculos, peso, altura, proporções, ascendência (africana, asiática, europeia), busto e firmeza. São os mesmos controles "macro" do MakeHuman. |
| Rosto e detalhes | Todos os modificadores do MakeHuman por região: cabeça, testa, sobrancelhas, olhos, nariz, boca, orelhas, queixo, bochechas, pescoço, tronco, quadril, braços e pernas. |
| Aparência | Pele, cor dos olhos, cabelo (longo liso, longo cacheado, curtos, chanel, crespo) e cores da raiz e das pontas, volume, roupa, peça superior (blusa clara e jeans ou terno/tailleur com camisa) e cor, gravata, sapato fechado, óculos, argolas, crachá com cordão, sorriso e barba. |
| Importar | Perfis do MakeHuman (`.mhm`), personagens do Avaturn e do Tripo3D (`.glb`) e geração no Tripo3D a partir de uma foto. |

Embaixo: **ID** (nome da pasta em `AVATARES`, letras minúsculas, números e `_`), **Nome** (como aparece na lista), **Prévia 3D** (gera em pasta temporária, cerca de 30 s), **Gerar no Assistente** (grava em `AVATARES` e calibra os movimentos, alguns minutos), **Abrir/Salvar ficha**.

Depois de gerar, no Assistente clique em **↻** na lista de avatares.

## Ficha do avatar (`.avatar.json`)

Arquivo JSON com `format: "assistente-avatar-spec"`. Guarda os valores dos modificadores com os mesmos nomes do MakeHuman (por exemplo `macrodetails/Gender`, `nose/nose-scale-horiz-decr|incr`), a pele, a roupa, o cabelo e o bloco `style` (cores e acessórios). Cada avatar gerado leva a sua ficha em `AVATARES/<id>/ficha.avatar.json`, então dá para reabrir, ajustar e gerar de novo.

O formato dos pesos segue as regras do próprio MakeHuman: cada alvo "macro" recebe o produto dos valores dos componentes do nome (gênero, idade, músculo, peso, altura, proporções, ascendência, busto) e os modificadores de dois lados escolhem o alvo pelo sinal.

## MakeHuman

1. No MakeHuman 1.x, monte o personagem e salve (`.mhm`).
2. No Criador Avatar, **Importar → Abrir perfil do MakeHuman**.
3. O corpo e o rosto vêm exatos. Roupas, cabelos e peles que não existem no pacote do Assistente são trocados pelos mais próximos; o registro mostra cada troca. Ajuste o que quiser e gere.

Linha de comando: `python tools/avatar_spec.py import-mhm perfil.mhm --build`.

## Avaturn e Tripo3D

**Avaturn** (`hub.avaturn.me`): crie o avatar com fotos, exporte em `.glb` e use **Importar .glb exportado do Avaturn**.

**Tripo3D** (`studio.tripo3d.ai`): gere o personagem de pé, de frente, em pose T ou A, exporte em `.glb` e use **Importar .glb exportado do Tripo3D**. Também é possível gerar direto de uma foto pela API: informe a chave da API (área de API do Tripo) e clique em **Gerar no Tripo3D a partir de uma foto**. A chave vai apenas para `openapi.tripo3d.com`, em memória; não é gravada em arquivo nem no registro.

Como a importação funciona: o modelo mantém a própria malha e texturas. O programa identifica a pose dos braços, posiciona um corpo de referência do MakeHuman na mesma pose, transfere os pesos do esqueleto do Assistente para cada vértice, leva a malha para a pose padrão do Assistente e gera as animações e os movimentos calibrados.

Limites da importação:

- O personagem precisa estar de pé, de frente, em pose T ou A.
- Cabelo longo solto e saias amplas seguem a parte do corpo mais próxima.
- A boca e os olhos do modelo importado são movidos por ossos (o motor do Assistente ignora "morph targets"); a sincronização labial é aproximada.
- Proporções muito diferentes das humanas (personagens estilizados) podem deformar nas articulações.

Linha de comando: `python tools/glb_import.py modelo.glb --id nome --name "Nome" --source avaturn` e `python tools/tripo_client.py from-image foto.png --id nome --name "Nome" --rig` (com `TRIPO_API_KEY`).

## Arquivos

- `tools/criador_avatar/criador_avatar.lpr`: interface (Lazarus).
- `tools/avatar_spec.py`: ficha, cálculo dos pesos do MakeHuman, geração e calibração; importador `.mhm`.
- `tools/glb_import.py`: importação `.glb`/`.gltf` com transferência de pesos.
- `tools/tripo_client.py`: API v3 do Tripo3D (upload, modelo, esqueleto, download).
- `tools/avatar-source/mh-targets-*.npz`: os 1.280 alvos CC0 do MakeHuman compactados em três partes (`tools/pack_mh_targets.py`).
- `tools/avatar-source/mh-modifiers/`: definições dos modificadores do MakeHuman (CC0).
- `runtime/python/` (no instalador): Python 3.12 com numpy 2.0, scipy 1.14 e Pillow, usado só pelo gerador.

## Testes

- `tests/check_glb_import.py`: ida e volta de um corpo em pose T exportado em `.glb` (malha volta à pose padrão com erro de 1,3 mm, 65 clipes, 53 movimentos calibrados).
- `tests/check_tripo_client.py`: cliente do Tripo contra uma API simulada (upload, modelo, esqueleto, consulta, download e importação; a chave nunca é gravada).
- `tests/check_avatar_assets.py`, `check_avatar_body.py`, `check_avatar_gestures.py`, `check_avatar_motion.py`: incluem os novos avatares.

A integração com os sites do Avaturn e do Tripo depende do login e das regras de cada serviço; os testes usam arquivos e uma API simulada, sem conta real.
