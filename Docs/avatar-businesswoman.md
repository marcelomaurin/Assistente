# Executiva (Businesswoman)

Modelo importado de `modelos/businesswoman+3d+model3.glb`, fornecido pelo usuario.
SHA-256: `e5272254493e877a95b4ec3f1ae0570a43a06d62aff1d805b270e76e159abd67`.
O arquivo original permanece inalterado. As permissoes sobre a arte sao as do arquivo original; a importacao nao atribui licenca CC0 a esta personagem.

## Integracao

A personagem aparece como **Executiva (Businesswoman)** na selecao de avatares do Assistente e do editor de movimentos. O identificador e `businesswoman`.

O segundo GLB contem 78 ossos com pesos de pele, 14 malhas e 28 texturas. O importador `tools/tripo_rig_import.py` aproveita essa estrutura e mapeia os ossos para os 163 controles do Assistente. Preserva as texturas e materiais PBR, alinha a pose de referencia e corrige influencias indevidas das maos sobre a calca e o casaco.

Foram gerados 65 clipes e calibrados os 53 movimentos do catalogo, incluindo uma trajetoria especifica para palmas. A protecao contra colisao permanece ativa. Os perfis dos demais avatares foram preservados.

## Validacao

- Carregamento pelo renderizador real CGE: geometria e 65 clipes aprovados.
- 53 movimentos isolados e 53 em sequencia: todos completam, sem bloqueio por colisao.
- Pesos normalizados, indices validos e 28 texturas identicas as originais.
- Inspecao visual das vistas frontal e lateral e do gesto de aceno.
- Regressao do importador de GLB sem rig e verificacoes do adaptador Tripo aprovadas.

Relatorios e imagens estao em `build/import-businesswoman`, incluindo `validation-final.json` e `preview-model3-clean`.

## Limites

A estrutura original permite movimentos corporais, das maos, dedos e olhos. Nao possui pesos separados para labios e palpebras; controles virtuais e nomes de clipes faciais nao representam expressividade facial completa. Esta parte requer uma rigagem facial adicional.

O avatar foi incluido nos arquivos do projeto e nas pastas executaveis `build/presentations-0215` e `build/voice-chrome-openai`. O instalador 0.215 ja gerado nao foi reconstruido nesta integracao.
