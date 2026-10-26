# Movimentos definidos em JSON

O Assistente e o Editor usam `AVATARES/movimentos.json`, junto do Assistente escolhido no editor. O catálogo padrão agora usa `version: 2`: seus 53 movimentos contêm trajetórias por membro. Novos movimentos não exigem recompilação nem novos clipes no modelo.

## Criar um movimento

Acrescente um objeto em `movements`, salve em UTF-8 e clique em **Recarregar**. No editor, selecione o item e use **Testar movimento** para escolher o avatar, reproduzir a 25%, 50% ou 100% e pausar. **Inserir tag** mantém o padrão `[nome do movimento]`.

Exemplo completo de catálogo mínimo:

```json
{
  "version": 2,
  "movements": [{
    "id": "pulso_personalizado",
    "tag": "pulso personalizado",
    "title": "Girar pulso direito",
    "category": "Mãos",
    "description": "Gira o pulso e volta à pose anterior.",
    "aliases": ["girar pulso"],
    "mode": "gesture",
    "duration_ms": 1000,
    "transition_ms": 0,
    "interpolation": "smooth",
    "finish": "return",
    "return_ms": 400,
    "members": [{
      "bone": "wrist.R",
      "start_ms": 0,
      "duration_ms": 1000,
      "initial_rotation_deg": "current",
      "final_rotation_deg": [0, 25, 0]
    }]
  }]
}
```

O exemplo produz `[pulso personalizado]`. `bone` é o nome exato do membro no glTF; `.L` representa o lado esquerdo do personagem, `.R` o direito. As rotações são locais, relativas à pose original, em graus XYZ. `initial_rotation_deg` aceita três números ou `"current"`, que captura a pose existente quando o movimento começa. A pose capturada pertence a essa execução, sem alterar o catálogo compartilhado.

Cada membro tem `start_ms` e `duration_ms`, dentro da duração geral. Membros com o mesmo início se movem juntos; tempos diferentes criam uma sequência. `transition_ms` prepara a posição inicial; `finish: "hold"` mantém o resultado e `finish: "return"` retorna à pose recebida. O tempo total é transição + duração + retorno, quando solicitado. As tags seguintes da apresentação aguardam esse tempo. O retorno também passa pela verificação de colisão.

O programa interpola rotações por quaternion e deslocamentos por interpolação linear, com suavização opcional (`smooth` ou `linear`). Divide o tempo em intervalos de no máximo 10 ms, respeitando também cada ponto da trajetória. O tempo vem da reprodução, não da quantidade de quadros; pausar congela a execução e a prévia lenta aplica a velocidade escolhida.

## Pontos intermediários

Para contornar o corpo ou fazer uma ida e volta, substitua os campos inicial/final por `keyframes`:

```json
{
  "bone": "wrist.R",
  "start_ms": 0,
  "duration_ms": 1000,
  "keyframes": [
    {"time_ms": 0, "rotation_deg": [0, 0, 0]},
    {"time_ms": 500, "rotation_deg": [0, 25, 0]},
    {"time_ms": 1000, "rotation_deg": [0, 0, 0]}
  ]
}
```

Os tempos são relativos ao membro, estritamente crescentes, incluindo zero e o fim. Todas as propriedades usadas precisam aparecer em todos os pontos. No primeiro ponto, `rotation_deg`, `position_height` e `scale` também aceitam `"current"`, capturando a posição existente para iniciar uma sequência de etapas sem saltos. Rotações seguem o arco mais curto; uma volta de 360 graus exige pontos intermediários.

`initial_position_height`/`final_position_height` ou `position_height` nos pontos definem deslocamentos locais relativos à altura do avatar e à posição original. Somente os membros autorizados em `translatable_members` podem se deslocar: transladar ossos dos braços/pernas alteraria seu comprimento. `initial_scale`/`final_scale` ou `scale` permitem escalas positivas em elementos faciais. Escalar membros que sustentam volumes de colisão é proibido. Os campos iniciais de posição e escala também aceitam `"current"`.

`profiles` permite substituir a trajetória por avatar, usando o ID da pasta como chave e uma receita completa com os mesmos tempos e política de retorno. O catálogo instalado contém as adaptações dos dezoito personagens; o Criador Avatar acrescenta as dos avatares que gerar. `speech_mouth: true` reserva a mandíbula durante o bocejo.

## Proteção contra colisão

`AVATARES/colisoes.json` contém cápsulas e esferas para tronco, cabeça, braços, antebraços, mãos e pernas. Os raios, margens e deslocamentos são proporcionais à altura de referência registrada em `reference_heights` por ID do avatar. Essa referência é fixa, independente da caixa de enquadramento calculada pelo renderizador. Atualize-a ao alterar a escala do modelo. Cada volume tem `id`, `start_bone`, `end_bone` e `radius_height`; `start_fraction`/`end_fraction` e `start_offset_height`/`end_offset_height` ajustam a cobertura. `ignored_pairs` exclui apenas os contatos entre partes adjacentes que compartilham uma articulação.

O motor verifica o percurso entre poses, além das posições finais. Ao prever contato, reduz o avanço até a última pose segura e para; a prévia informa o par envolvido. A proteção permanece habilitada. Não há desvio automático: ajuste o percurso com pontos intermediários e teste novamente. Os percursos padrão são calibrados por avatar para concluir os gestos com a proteção ativa. Trajetórias novas que toquem os volumes protegidos são interrompidas e precisam de ajuste.

As cápsulas são aproximações do corpo, não uma simulação das superfícies exatas da pele, roupas e acessórios. Calibre seus volumes ao modificar um avatar; a proteção cobre os volumes configurados. Modelos com transformações matriciais ou escala inicial diferente de um precisam de normalização antes de usar este motor. Perfis inválidos ou ausentes impedem a execução de movimentos e mostram um aviso.

Depois de editar o perfil, use **Recarregar** no Assistente ou reinicie a prévia para carregá-lo novamente. O editor usa o perfil que fica junto do Assistente escolhido.

## Compatibilidade e distribuição

Catálogos antigos de versão 1 com `clip`/`joints` continuam aceitos, com proteção na reprodução. O padrão de versão 2 não depende de clipes para definir os movimentos. O carregamento valida todo o arquivo antes de substituir o catálogo ativo: de 1 a 512 movimentos, até 32 MiB, nomes únicos e tempos válidos.

O instalador atualiza os catálogos originais intactos de 0.210, 0.211 e 0.212. Atualiza também o perfil de colisão original intacto da 0.212. Preserva catálogos e perfis de colisão personalizados; para migrar um catálogo editado, use este exemplo e mantenha uma cópia de segurança. Distribua os dois aplicativos com a mesma pasta `AVATARES`. `ASSISTENTE_MOVEMENTS_FILE` permite selecionar outro catálogo; o perfil de colisão deve estar na mesma pasta.

## Integração de animações externas validada em 24/10/2026

`animation_file` aceita somente o nome de um JSON, por exemplo `aceno.json`; o arquivo fica em `AVATARES/movimentos/`, junto ao catálogo selecionado. Não inclua `movimentos/` no valor do campo. Arquivos `assistente-motion` versões 1 e 2 são carregados e validados durante a recarga do catálogo. A v1 mantém um eixo escalar por membro; a v2 permite poses XYZ simultâneas com `axis: "xyz"` e quadros `rotation_deg: [x,y,z]`. Alterar somente esse recurso exige **Recarregar** ou reiniciar o aplicativo.

Quando uma entrada possui `members`, essas trajetórias e suas variantes por avatar têm prioridade sobre `animation_file`. O catálogo integrado mantém 41 referências externas como alternativas históricas, mas executa os 53 percursos internos calibrados. Editar somente um desses arquivos externos não altera a animação dessa entrada. Para usar um recurso externo, crie uma entrada sem `members`/`profiles`, com `animation_file`, ou substitua a receita conscientemente e teste as colisões de cada avatar. Não misture `clip` e `animation_file`.

A duração do recurso externo é a duração efetiva, independentemente do valor informativo do catálogo. O motor acrescenta `transition_ms` na entrada e, se `return_to_base` estiver ativo, um retorno com duração igual à transição, com mínimo de 50 ms. `loop` repete esse ciclo até outro movimento ou reset; a fila de fala aguarda um ciclo e pode então substituí-lo. A mesma interpolação angular é usada no editor e na reprodução, inclusive entre ângulos cuja diferença excede 180 graus. Pausa e velocidade de reprodução usam o tempo do motor, com proteção de colisão também durante o retorno.

O Editor de Movimentos é uma prévia independente: seleciona membros no avatar, oferece anéis XYZ, campos numéricos simultâneos, grava poses e aplica a linha do tempo ao modelo. O layout e a câmera seguem o MultiCNC, com vistas CAD, órbita, deslocamento e zoom. Edição de curvas/trilhas, IK, undo/redo, exclusão de quadros e cadastro de tags continuam pendentes. Consulte o [guia atualizado](editor-movimentos.md).
