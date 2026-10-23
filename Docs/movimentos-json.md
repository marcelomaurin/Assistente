# Catálogo compartilhado de movimentos

O Assistente e o Editor de Apresentações usam o mesmo arquivo
`AVATARES/movimentos.json`, ao lado dos executáveis da instalação. O editor
também pode carregar o catálogo junto do Assistente escolhido no campo de conexão.

As tags, os apelidos, os títulos mostrados na biblioteca, as instruções enviadas
à IA, os clipes e as durações vêm desse JSON. Cadastrar um movimento não exige
alterar enums nem recompilar os aplicativos. As constantes antigas continuam
existindo apenas para compatibilidade com integrações e testes anteriores.

## Como incluir um movimento

1. Acrescente um objeto à lista `movements`, com um `id` único.
2. Informe a tag, o título e um clipe existente no avatar, ou uma lista `joints`.
3. Salve o JSON em UTF-8 e use **Recarregar** na biblioteca dos dois aplicativos.
4. No editor, pesquise o título e use **Inserir tag** ou dê duplo clique.
5. No Assistente, selecione o movimento e use **Executar gesto**.

Exemplo de novo nome para um clipe existente:

```json
{
  "id": "saudacao_especial",
  "tag": "saudacao especial",
  "title": "Saudação especial",
  "category": "Mãos",
  "description": "Acena com a mão direita para cumprimentar.",
  "aliases": ["cumprimento especial"],
  "mode": "gesture",
  "clip": "wave",
  "duration_ms": 2400,
  "transition_ms": 320
}
```

Exemplo de pose nova, definida diretamente por articulações:

```json
{
  "id": "pulso_personalizado",
  "tag": "pulso personalizado",
  "title": "Girar o pulso direito",
  "category": "Mãos",
  "description": "Mantém o pulso direito girado em 25 graus.",
  "mode": "pose",
  "joints": [
    {"bone": "wrist.R", "axis": "y", "angle": 25, "duration_ms": 600}
  ]
}
```

`gesture` é transitório e usa `duration_ms`; `pose` permanece até outra pose
ou `[neutro]`. `transition_ms` controla a mistura entre clipes. As articulações
usam interpolação suave e sua própria duração. Uma nova composição de
articulações substitui a composição anterior criada pelo catálogo.

`talking_clip` pode escolher outro clipe quando o personagem estiver falando.
`speech_mouth: true` reserva a mandíbula para um gesto transitório como o bocejo.
Os modos de controle são `reset`, `smile`, `raise_right`, `lower_right`,
`clear_pose`, `lower_both` e `stop`.

O catálogo não gera clipes nem malhas 3D. Para um movimento complexo novo, crie
o clipe no modelo e informe seu nome no JSON. Para uma pose simples nova,
defina as articulações no próprio catálogo. O avatar selecionado precisa ter
os ossos ou clipes solicitados; a interface avisa quando estiverem ausentes.

## Execução em sequência

Tags de movimento consecutivas respeitam o tempo de cada gesto no JSON.
Uma pose aguarda sua transição e as articulações antes do próximo movimento.
O último movimento também termina antes de `[FIM]` ou do encerramento da
apresentação. Pausar suspende essa contagem; Esc interrompe a espera.

No campo de conversa do Assistente, uma entrada contendo apenas tags, como
`[dar tchau][gesticular ok]`, executa os movimentos diretamente, sem consultar
a IA. Perguntas em texto continuam usando a conversa normal.

## Validação e distribuição

O documento tem `version: 1` e de 1 a 512 movimentos. IDs, tags e aliases não
podem colidir entre movimentos. Não são aceitos comandos de sistema, caminhos
de execução ou código. As articulações respeitam os limites do rig: dedos,
punhos, braços, ombros, cabeça, coluna e pernas; a mandíbula fica reservada
à fala e aos clipes faciais. Eixos válidos: `x`, `y` e `z`.

O carregamento valida o documento inteiro antes de substituir o catálogo ativo.
Um recarregamento inválido informa o erro e não aplica uma lista parcial.
As alterações válidas também são verificadas pelo leitor de tags quando a
data de modificação do arquivo muda; o botão **Recarregar** força a atualização.

Os scripts de compilação e instalação já copiam `AVATARES` recursivamente,
incluindo o JSON. Distribua os dois executáveis com a mesma pasta `AVATARES`.
`ASSISTENTE_MOVEMENTS_FILE` permite indicar outro arquivo na inicialização,
principalmente para testes e instalações administradas.

Os testes `movement_catalog_tests.lpr` e `modern_ui_tests.lpr` adicionam
movimentos durante a execução e verificam biblioteca, busca, inserção,
desfazer, instruções da IA, fila de fala, clipes e articulações renderizadas.

O instalador atualiza o catálogo padrão original da versão 0.210 para corrigir
os apelidos dos braços. Catálogos personalizados continuam preservados.
