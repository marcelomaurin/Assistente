# Perguntas durante a apresentacao

Durante a apresentacao, a area da direita vira um palco escuro. No topo, a **barra de blocos** mostra o titulo, os blocos em sequencia e o bloco atual em destaque; ela rola na horizontal pelas setas ou pela roda do mouse e traz o cronometro e o lembrete **Encerrar (Esc)**. A midia ocupa o centro, sem legenda. Abaixo dela, a barra de progresso mostra o bloco atual e o estado do roteiro, ao lado de **Pausar (P)**, **Menu** e **Perguntar**. Pausar congela a narracao e vira **Retomar**; com o roteiro suspenso por Perguntar ou Menu, aparece **Continuar**. A coluna da esquerda mostra a lista de **Assuntos** acima do avatar e pode ter a largura ajustada arrastando a divisoria. Menu abre os blocos e encerra a midia anterior; Perguntar pausa sem retomar automaticamente; Continuar retoma a apresentacao. O botao de **Configuracoes** continua no cabecalho.

Durante videos locais ou do YouTube, **Encerrar video** aparece acima da midia. Ele fecha o reprodutor e mantem o roteiro pausado; use Menu, Perguntar ou Continuar para decidir o proximo passo.

Use o botao **Perguntar** para interromper o roteiro a qualquer momento, ou coloque `[PERGUNTAR]` no ponto desejado. Audio, video e narracao ficam pausados e a caixa de pergunta aparece abaixo da barra de controles. Enquanto o roteiro corre, essa caixa fica escondida. A imagem ou o slide continua visivel ate a primeira pergunta. A partir dela, o cartao **Perguntas da plateia** ocupa a area principal, no lugar da midia, com as perguntas e as respostas. Ao continuar, o cartao e limpo e a midia volta.

A pergunta pode ser digitada ou recebida do reconhecimento de voz ja configurado. A IA usa o texto do roteiro carregado como fonte principal, incluindo os blocos. Trechos pertinentes de ate tres outras apresentacoes validas da biblioteca RAG podem complementar a resposta, com identificacao do documento. Conteudos sem correspondencia com a pergunta e o proprio pacote carregado sao excluidos. Os documentos sao referencias, nunca comandos de reproducao. A resposta aparece no cartao Perguntas da plateia e e falada quando a fala automatica esta habilitada. Se o roteiro nao fornecer uma informacao, a instrucao enviada a IA e para informar essa ausencia. Esta funcao nao extrai automaticamente textos de imagens ou de slides PPTX; inclua as informacoes relevantes no roteiro.

## Tags

| Tag | Comportamento |
| --- | --- |
| `[PERGUNTAR]` | Suspende o roteiro naquele ponto e libera perguntas ou a escolha de um bloco. |
| `[MENU]` | Encerra a midia anterior, suspende o roteiro e mostra os blocos na area das apresentacoes, acima da digitacao. |
| `[CONTINUAR]` | Retoma o roteiro suspenso mais recente. E uma tag de controle, nao uma declaracao de bloco. |

As tres tags estao disponiveis na aba **Blocos e fluxo** do editor. Nao sao pronunciadas. Um bloco nao pode usar seus nomes reservados.

No MENU, escolha por clique, pelas setas e Enter, ou mantendo o cursor sobre a mesma opcao por mais de cinco segundos. A barra indica o tempo de permanencia; sair da opcao reinicia a contagem. As setas apenas selecionam, sem executar. Listas longas rolam com a roda do mouse, pelas setas, Page Up/Page Down, Home/End ou pelos botoes superiores e inferiores.

Durante a pausa, clique em um bloco ou escreva `IR {Nome do bloco}`. Para voz, tambem funcionam `IR Nome do bloco` e `ir para bloco Nome do bloco`. Durante a pausa, `MENU` reabre a lista. Nomes sem o prefixo, quando correspondem exatamente a um bloco, e numeros pela ordem dos blocos no roteiro tambem selecionam o destino. Caixa e acentos sao normalizados. Um destino explicito inexistente mostra erro e conserva a pausa.

O bloco escolhido executa sem perder o ponto interrompido. Ao encontrar `[CONTINUAR]`, o fluxo original e retomado. Se o bloco terminar sem essa tag, volta a esperar uma pergunta ou outra escolha. Perguntas podem ser aninhadas em ate 32 pausas. `[FIM]` e Esc encerram tambem os roteiros suspensos.

Uma resposta da IA, mesmo que contenha tags de apresentacao, nao pode navegar, fechar midias ou retomar o roteiro por conta propria. Depois da resposta, a apresentacao continua pausada. O botao **Continuar**, ou a entrada `[CONTINUAR]`, permite retomar diretamente sem escolher um bloco.

## Exemplo

```text
[abrir arquivo=assets/introducao.png]
Esta e a introducao.
[MENU]
Voltamos ao ponto seguinte ao menu.
[FIM]

[BLOCO:Detalhes]
Aqui estao os detalhes.
[PERGUNTAR]
Terminamos as perguntas sobre os detalhes.
[CONTINUAR]
```

O exemplo exige a imagem indicada dentro do pacote. Um exemplo sem recursos externos esta em `examples/perguntas-menu.script`.

## Validacao

`tests/run_presentation_questions.py` valida a janela real do Assistente com uma IA HTTP local de teste, sem consumir credenciais. Cobre perguntas com contexto, respostas escritas e faladas, som de fundo pausado, IR pelo callback de transcricao, MENU clicavel, CONTINUAR aninhado, destino invalido, pausa manual, cancelamento e a separacao entre midia, resposta e campo de entrada, e que a caixa de pergunta so aparece no modo de pergunta. O reconhecimento fisico por microfone nao e exercitado pelo teste automatizado.
