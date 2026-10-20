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

Os dez modelos incluídos são malhas 3D originais, articuladas e estilizadas,
com detalhes geométricos de rosto, cabelo, mãos, roupas e acessórios. Não são
imagens planas. As referências fornecidas orientam o estilo, sem reprodução
exata das malhas ou da qualidade de uma produção artística profissional.
O gerador reproduzível é `tools/generate_professor.py`.
