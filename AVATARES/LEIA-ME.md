# Incluir avatares

Copie um `.glb`/`.gltf` para esta pasta ou crie uma subpasta por personagem.
Texturas e arquivos `.bin` devem acompanhar o `.gltf`, preservando os caminhos.
No cartão do avatar, clique em **↻** para atualizar a lista, sem recompilar.

Para nome e identificação estáveis, inclua `avatar.json` na subpasta:

```json
{"id":"meu-professor","name":"Meu professor","model":"modelo.glb"}
```

Use IDs únicos. A aplicação também descobre arquivos sem manifesto. Manifestos
inválidos não impedem a abertura dos demais modelos. O diagnóstico aparece na
dica do seletor. A busca inclui até seis níveis de subpastas.

O modelo deve estar em pé em Y e olhando para +Z, com a origem próxima aos pés.
Clipes esperados: `idle`, `listening`, `thinking`, `talking`, `wave`, `walk`.
Para outros nomes, use `modelo.ini` junto de `modelo.glb` ou `modelo.gltf`:

```ini
[animations]
idle=Idle
listening=Listen
thinking=Think
talking=Talk
wave=Wave
walk=Walk
```

Roda para cima aproxima; para baixo afasta. O zoom tem limites. Duplo clique
reenquadra. Trocar de personagem também restaura o enquadramento.

Os dez modelos v3 usam recursos gráficos CC0 do MakeHuman, adaptados para
personagens de tempo real: anatomia contínua, 163 juntas, quatro pesos por
vértice, UVs, texturas de pele/cabelo/tecido e materiais com normais e oclusão.
Cada modelo tem 28 clipes, incluindo combinações de fala, sorriso e mão direita
levantada, e morph targets de boca, pálpebras e sorriso. Os movimentos são
criados e amostrados a 60 Hz, com transições suaves no renderer.

A IA pode inserir tags como `[sorriso]`, `[aplausos]`, `[levantar mao direita]`
e `[abaixar mao direita]` na resposta. Consulte `docs/avatar-comandos-ia.md`.
Um arquivo externo precisa fornecer seus próprios clipes para esses comandos;
o sistema não faz rigging automático. Escolher uma profissão muda a aparência.

As referências orientam o estilo, sem reprodução exata nem promessa de
fotorrealismo. O gerador reproduzível é `tools/generate_professor.py` e requer
numpy/Pillow somente na geração. Fontes, licença e proveniência estão em
`tools/avatar-source/`; a aplicação não requer Python ou MakeHuman instalado.
